//
//  TasksTabView.swift
//  Taskmato
//

import SwiftUI

/// The task picker tab, showing tasks grouped into sections with live search.
///
/// A ``NavigationSplitView`` places the ``ProviderSidebarView`` in the collapsible
/// sidebar column and the task list/grid in the detail column. Selecting a task
/// sets it as the active task and switches to the Timer tab. Section headers are
/// formatted as "List: Section" when multiple lists are active, or just "Section"
/// when only one list is active. Supports toggling between a list and an adaptive
/// card grid layout.
///
/// When at least one enabled provider conforms to ``ClosableTaskProvider``, a
/// "Show Completed" toolbar button becomes available. Toggling it on fetches
/// completed tasks and appends them inline at the bottom of each matching section.
struct TasksTabView: View {

  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  @Binding var selectedTab: Int
  @Bindable var settings: AppSettings

  @Environment(\.openSettings) private var openSettings

  @State private var query: String = ""
  @State private var groupedLists: [TaskGroup] = []
  @State private var isLoading: Bool = false
  @State private var isAddingTask = false
  @State private var showCompleted = false
  @State private var completedByListID: [String: [TaskItem]] = [:]
  @State private var completedOrphans: [TaskItem] = []
  @State private var isLoadingCompleted = false

  /// The local provider instance looked up from the registry, if registered.
  private var localProvider: LocalProvider? {
    registry.providers.first(where: { $0 is LocalProvider }) as? LocalProvider
  }

  private var remindersProvider: RemindersProvider? {
    registry.providers.first(where: { $0 is RemindersProvider }) as? RemindersProvider
  }

  /// `true` when the local provider is registered and currently enabled.
  private var localProviderEnabled: Bool {
    localProvider.map { registry.isEnabled($0.id) } ?? false
  }

  /// `true` when at least one enabled provider conforms to ``ClosableTaskProvider``.
  private var hasClosableProvider: Bool {
    registry.providers.contains { registry.isEnabled($0.id) && $0 is (any ClosableTaskProvider) }
  }

  /// Total number of completed tasks currently loaded across all sections and orphans.
  private var totalCompletedCount: Int {
    completedByListID.values.reduce(0) { $0 + $1.count } + completedOrphans.count
  }

  /// Flat display sections derived from `groupedLists`.
  ///
  /// Header labels collapse list and section names following these rules:
  /// - Multiple lists + has section → "List: Section"
  /// - Multiple lists + no section → "List"
  /// - Single list + has section → "Section"
  /// - Single list + no section → "List"
  private var flatSections: [FlatSection] {
    let multipleGroups = groupedLists.count > 1
    return groupedLists.flatMap { group in
      group.sections.map { section in
        let header: String
        switch (multipleGroups, section.name) {
        case (true, let name?): header = "\(group.listName): \(name)"
        case (true, nil): header = group.listName
        case (false, let name?): header = name
        case (false, nil): header = group.listName
        }
        return FlatSection(
          id: "\(group.id).\(section.id)", listID: group.id, header: header, tasks: section.tasks
        )
      }
    }
  }

  var body: some View {
    NavigationSplitView(
      columnVisibility: Binding(
        get: { settings.sidebarVisible ? .all : .detailOnly },
        set: { settings.sidebarVisible = $0 != .detailOnly }
      )
    ) {
      ProviderSidebarView(registry: registry)
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
    } detail: {
      detailContent
        .searchable(text: $query, prompt: "Search tasks")
        .task(id: query) { await loadTasks() }
        .task { await subscribeToProviderUpdates() }
        .onAppear { Task { await loadTasks() } }
        .onChange(of: isAddingTask) { _, adding in
          if !adding { Task { await loadTasks() } }
        }
        .onChange(of: registry.enabledIDs) { _, _ in Task { await loadTasks() } }
        .onChange(of: registry.selection) { _, _ in Task { await loadTasks() } }
        .onChange(of: registry.providerLists) { _, _ in Task { await loadTasks() } }
        .onChange(of: remindersProvider?.isAuthorized) { _, authorized in
          guard authorized == true else { return }
          Task { await loadTasks() }
        }
        .sheet(isPresented: $isAddingTask) {
          if let provider = localProvider {
            AddTaskView(provider: provider, isPresented: $isAddingTask)
          }
        }
        .toolbar {
          if localProviderEnabled {
            ToolbarItem(placement: .automatic) {
              Button {
                isAddingTask = true
              } label: {
                Label("Add Task", systemImage: "plus")
              }
              .help("Add a local task")
            }
          }

          if hasClosableProvider {
            ToolbarItem(placement: .automatic) {
              Button {
                showCompleted.toggle()
                if showCompleted { Task { await loadCompleted() } }
              } label: {
                Label(
                  showCompleted ? "Hide Completed" : "Show Completed",
                  systemImage: showCompleted ? "eye.slash" : "eye"
                )
              }
              .help(showCompleted ? "Hide completed tasks" : "Show completed tasks")
            }
          }

          ToolbarItem(placement: .automatic) {
            Picker("Layout", selection: $settings.taskPickerLayout) {
              Label("List", systemImage: "list.bullet").tag(TaskPickerLayout.list)
              Label("Grid", systemImage: "square.grid.2x2").tag(TaskPickerLayout.grid)
            }
            .pickerStyle(.segmented)
            .help("Toggle between list and grid view")
          }

          ToolbarItem(placement: .automatic) {
            Button {
              openSettings()
            } label: {
              Label("Settings", systemImage: "gearshape")
            }
            .help("Open Settings (⌘,)")
          }
        }
    }
  }

  // MARK: - Detail content

  @ViewBuilder
  private var detailContent: some View {
    if registry.providers.filter({ registry.isEnabled($0.id) }).isEmpty {
      ContentUnavailableView(
        "No Task Providers",
        systemImage: "tray",
        description: Text("Add a task provider using the sidebar.")
      )
    } else if isLoading {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if groupedLists.isEmpty {
      ContentUnavailableView(
        query.isEmpty ? "No Tasks" : "No Results",
        systemImage: query.isEmpty ? "checkmark.circle" : "magnifyingglass",
        description: Text(
          query.isEmpty
            ? "All tasks from your providers will appear here."
            : "No tasks match \"\(query)\"."
        )
      )
    } else if settings.taskPickerLayout == .grid {
      taskGrid
    } else {
      taskList
    }
  }

  // MARK: - List layout

  private var taskList: some View {
    List {
      if showCompleted {
        SwiftUI.Section {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(Color.accentColor)
            Text("\(totalCompletedCount) Completed")
              .foregroundStyle(.secondary)
            Spacer()
            Button("Hide") { showCompleted = false }
              .buttonStyle(.plain)
              .foregroundStyle(Color.accentColor)
          }
          .padding(.vertical, 2)
        }
      }

      SwiftUI.ForEach(flatSections) { section in
        listSection(for: section)
      }

      if showCompleted && !completedOrphans.isEmpty {
        SwiftUI.Section {
          SwiftUI.ForEach(completedOrphans) { task in completedRow(task) }
        } header: {
          Text("Other Completed")
            .font(.subheadline)
            .fontWeight(.semibold)
        }
      }
    }
  }

  @ViewBuilder
  private func listSection(for section: FlatSection) -> some View {
    let isLastForList = flatSections.last(where: { $0.listID == section.listID })?.id == section.id
    let completed = isLastForList ? (completedByListID[section.listID] ?? []) : []
    SwiftUI.Section {
      SwiftUI.ForEach(section.tasks) { task in
        TaskRowView(
          task: task,
          onComplete: registry.closableProvider(for: task.id) != nil
            ? { handleComplete(task) }
            : nil
        )
        .onTapGesture { select(task) }
      }
      if showCompleted && !completed.isEmpty {
        SwiftUI.ForEach(completed) { task in completedRow(task) }
      }
    } header: {
      Text(section.header)
        .font(.subheadline)
        .fontWeight(.semibold)
    }
  }

  /// A ``CompletedTaskRowView`` wired to this view's restore and delete handlers.
  @ViewBuilder
  private func completedRow(_ task: TaskItem) -> some View {
    CompletedTaskRowView(
      task: task,
      onRestore: { handleRestore(task) },
      onDelete: registry.provider(for: task.id) is (any WritableTaskProvider)
        ? { handleDelete(task) } : nil
    )
  }

  /// A ``CompletedTaskCardView`` wired to this view's restore and delete handlers.
  @ViewBuilder
  private func completedCard(_ task: TaskItem) -> some View {
    CompletedTaskCardView(
      task: task,
      onRestore: { handleRestore(task) },
      onDelete: registry.provider(for: task.id) is (any WritableTaskProvider)
        ? { handleDelete(task) } : nil
    )
  }

  // MARK: - Grid layout

  private var taskGrid: some View {
    let columns = [GridItem(.adaptive(minimum: 180), spacing: 10)]
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if showCompleted {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(Color.accentColor)
            Text("\(totalCompletedCount) Completed")
              .foregroundStyle(.secondary)
            Spacer()
            Button("Hide") { showCompleted = false }
              .buttonStyle(.plain)
              .foregroundStyle(Color.accentColor)
          }
          .padding(.horizontal, 2)
        }

        ForEach(flatSections) { section in
          let isLastForList =
            flatSections.last(where: { $0.listID == section.listID })?.id == section.id
          let completed = isLastForList ? (completedByListID[section.listID] ?? []) : []
          VStack(alignment: .leading, spacing: 8) {
            Text(section.header)
              .font(.subheadline)
              .fontWeight(.semibold)
              .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: 10) {
              ForEach(section.tasks) { task in
                TaskCardView(
                  task: task,
                  onComplete: registry.closableProvider(for: task.id) != nil
                    ? { handleComplete(task) }
                    : nil
                )
                .onTapGesture { select(task) }
              }
            }

            if showCompleted && !completed.isEmpty {
              LazyVGrid(columns: columns, spacing: 10) {
                ForEach(completed) { task in completedCard(task) }
              }
            }
          }
        }

        if showCompleted && !completedOrphans.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Other Completed")
              .font(.subheadline)
              .fontWeight(.semibold)
              .padding(.horizontal, 2)
            LazyVGrid(columns: columns, spacing: 10) {
              ForEach(completedOrphans) { task in completedCard(task) }
            }
          }
        }
      }
      .padding(10)
    }
  }

}

// MARK: - Data loading

extension TasksTabView {

  /// Subscribes to live-update streams from all enabled providers and reloads tasks on each event.
  private func subscribeToProviderUpdates() async {
    await withTaskGroup(of: Void.self) { group in
      for provider in registry.providers where registry.isEnabled(provider.id) {
        guard let stream = provider.observe() else { continue }
        group.addTask {
          for await _ in stream {
            await loadTasks()
          }
        }
      }
    }
  }

  private func loadTasks() async {
    isLoading = groupedLists.isEmpty
    let (tasks, _) = await registry.tasks(
      matching: query, selection: registry.selection,
      sortBy: .priority, direction: .descending)
    groupedLists = buildGroups(from: tasks)
    isLoading = false
  }

  private func loadCompleted() async {
    isLoadingCompleted = true
    var byList: [String: [TaskItem]] = [:]
    var orphans: [TaskItem] = []
    let activeListIDs = Set(flatSections.map(\.listID))
    for provider in registry.providers where registry.isEnabled(provider.id) {
      guard let closable = provider as? (any ClosableTaskProvider) else { continue }
      let items = (try? await closable.completedTasks()) ?? []
      for item in items {
        let key = item.list?.id ?? ""
        if !key.isEmpty && activeListIDs.contains(key) {
          byList[key, default: []].append(item)
        } else {
          orphans.append(item)
        }
      }
    }
    completedByListID = byList
    completedOrphans = orphans.sorted {
      ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
    }
    isLoadingCompleted = false
  }

  private func select(_ task: TaskItem) {
    selectionStore.select(task)
    selectedTab = 0
  }

  /// Completes the task via its closable provider, then refreshes the list.
  private func handleComplete(_ task: TaskItem) {
    let ref = task.id
    Task {
      if let provider = registry.closableProvider(for: ref) {
        try? await provider.complete(ref)
      }
      await loadTasks()
      if showCompleted { await loadCompleted() }
    }
  }

  /// Reopens a completed task via its closable provider, then refreshes both lists.
  private func handleRestore(_ task: TaskItem) {
    let ref = task.id
    Task {
      if let provider = registry.closableProvider(for: ref) {
        try? await provider.reopen(ref)
      }
      await loadTasks()
      await loadCompleted()
    }
  }

  /// Permanently deletes a completed task via its writable provider, then refreshes completed.
  private func handleDelete(_ task: TaskItem) {
    let ref = task.id
    Task {
      if let provider = registry.provider(for: ref) as? (any WritableTaskProvider) {
        try? await provider.deleteTask(ref)
      }
      await loadCompleted()
    }
  }

}

// MARK: - Grouping

extension TasksTabView {

  private func buildGroups(from tasks: [TaskItem]) -> [TaskGroup] {
    var ordered: [String] = []
    var byKey: [String: [TaskItem]] = [:]

    for task in tasks {
      let key = task.list?.id ?? ""
      if byKey[key] == nil { ordered.append(key) }
      byKey[key, default: []].append(task)
    }

    return ordered.compactMap { key -> TaskGroup? in
      guard let tasks = byKey[key], let list = tasks.first?.list else { return nil }
      let sections = buildSections(from: tasks)
      return TaskGroup(id: key, listName: list.name, sections: sections)
    }
  }

  private func buildSections(from tasks: [TaskItem]) -> [TaskSection] {
    var ordered: [String?] = []
    var bySection: [String?: [TaskItem]] = [:]

    for task in tasks {
      let key = task.section
      if bySection[key] == nil { ordered.append(key) }
      bySection[key, default: []].append(task)
    }

    return ordered.map { key in
      TaskSection(
        id: key ?? "_unsectioned_",
        name: key,
        tasks: bySection[key] ?? []
      )
    }
  }
}

#Preview {
  TasksTabView(
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    selectedTab: .constant(1),
    settings: AppSettings()
  )
}
