//
//  TasksTabView.swift
//  Taskmato
//

import SwiftUI

/// The task picker tab, showing tasks grouped into sections with live search.
///
/// A ``NavigationSplitView`` places the ``ProviderSidebarView`` in the sidebar and the
/// task list/grid in the detail column. Supports list and grid layouts. When at least one
/// enabled provider conforms to ``ClosableTaskProvider``, a "Show Completed" toolbar
/// button becomes available.
struct TasksTabView: View {

  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  @Binding var selectedTab: MainTab
  @Bindable var settings: AppSettings

  @State private var query: String = ""
  @State private var groupedLists: [TaskGroup] = []
  @State private var isLoading: Bool = false
  @State private var isAddingTask = false
  @State private var showCompleted = false
  @State private var completedByListID: [String: [TaskItem]] = [:]
  @State private var completedOrphans: [TaskItem] = []
  @State private var isLoadingCompleted = false

  private var localProvider: LocalProvider? {
    registry.providers.first(where: { $0 is LocalProvider }) as? LocalProvider
  }

  private var remindersProvider: RemindersProvider? {
    registry.providers.first(where: { $0 is RemindersProvider }) as? RemindersProvider
  }

  private var localProviderEnabled: Bool {
    localProvider.map { registry.isEnabled($0.id) } ?? false
  }

  private var hasClosableProvider: Bool {
    registry.providers.contains { registry.isEnabled($0.id) && $0 is (any ClosableTaskProvider) }
  }

  private var totalCompletedCount: Int {
    completedByListID.values.reduce(0) { $0 + $1.count } + completedOrphans.count
  }

  private var flatSections: [FlatSection] {
    Taskmato.flatSections(from: groupedLists)
  }

  /// Context affordance shown at the top of the task list and grid.
  private var affordanceInfo: (icon: String, label: String)? {
    if !query.isEmpty {
      let count = flatSections.reduce(0) { $0 + $1.tasks.count }
      let label = isLoading ? "Searching…" : "\(count) \(count == 1 ? "result" : "results")"
      return ("magnifyingglass", label)
    }
    if registry.selection == .today { return ("calendar", "Today") }
    guard case .list(let sel) = registry.selection, let grp = groupedLists.first else { return nil }
    let icon = registry.providers.first(where: { $0.id == sel.providerID })?.icon ?? "list.bullet"
    return (icon, grp.listName)
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
    }
    .searchable(text: $query, placement: .toolbar, prompt: "Search tasks")
    .task(id: query) { await loadTasks() }
    .task { await subscribeToProviderUpdates() }
    .onAppear { Task { await loadTasks() } }
    .onChange(of: isAddingTask) { _, adding in
      if !adding { Task { await loadTasks() } }
    }
    .onChange(of: registry.enabledIDs) { _, _ in Task { await loadTasks() } }
    .onChange(of: registry.selection) { _, _ in
      query = ""
      Task { await loadTasks() }
    }
    .onChange(of: registry.providerLists) { _, _ in Task { await loadTasks() } }
    .onChange(of: settings.taskSortField) { _, _ in Task { await loadTasks() } }
    .onChange(of: settings.taskSortDirection) { _, _ in Task { await loadTasks() } }
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
        sortMenu
      }
    }
  }

  // MARK: - Detail content

  @ViewBuilder
  private var detailContent: some View {
    if registry.providers.filter({ registry.isEnabled($0.id) }).isEmpty {
      ContentUnavailableView(
        "Enable a Provider",
        systemImage: "plus.circle",
        description: Text("Enable a provider in the sidebar to get started.")
      )
    } else if registry.selection == nil {
      ContentUnavailableView(
        "Select a List",
        systemImage: "sidebar.left",
        description: Text("Select a list in the sidebar.")
      )
    } else if isLoading {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if groupedLists.isEmpty {
      if !query.isEmpty {
        ContentUnavailableView(
          "No Results",
          systemImage: "magnifyingglass",
          description: Text("No tasks match \"\(query)\".")
        )
      } else if registry.selection == .today {
        ContentUnavailableView(
          "No Tasks Due Today",
          systemImage: "sun.max",
          description: Text("Tasks due today or overdue will appear here.")
        )
      } else {
        ContentUnavailableView(
          "No Tasks",
          systemImage: "checkmark.circle",
          description: Text("No tasks in this list.")
        )
      }
    } else if settings.taskPickerLayout == .grid {
      taskGrid
    } else {
      taskList
    }
  }

  // MARK: - List layout

  private var taskList: some View {
    List {
      if let info = affordanceInfo {
        SwiftUI.Section {
          HStack(spacing: 6) {
            Image(systemName: info.icon).foregroundStyle(Color.accentColor)
            Text(info.label).foregroundStyle(.secondary)
            Spacer()
          }
          .padding(.vertical, 2)
        }
      }

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
        Button {
          select(task)
        } label: {
          TaskRowView(task: task, onComplete: onCompleteHandler(for: task))
        }
        .buttonStyle(.plain)
        .contextMenu { taskContextMenu(for: task) }
      }
      if showCompleted && !completed.isEmpty {
        SwiftUI.ForEach(completed) { task in completedRow(task) }
      }
    } header: {
      if affordanceInfo?.label != section.header {
        Text(section.header).font(.subheadline).fontWeight(.semibold)
      }
    }
  }

  /// A ``CompletedTaskRowView`` wired to this view's restore and delete handlers.
  private func completedRow(_ task: TaskItem) -> some View {
    CompletedTaskRowView(
      task: task,
      onRestore: { handleRestore(task) },
      onDelete: registry.provider(for: task.id) is (any WritableTaskProvider)
        ? { handleDelete(task) } : nil
    )
    .contextMenu { completedTaskContextMenu(for: task) }
  }

  /// A ``CompletedTaskCardView`` wired to this view's restore and delete handlers.
  private func completedCard(_ task: TaskItem) -> some View {
    CompletedTaskCardView(
      task: task,
      onRestore: { handleRestore(task) },
      onDelete: registry.provider(for: task.id) is (any WritableTaskProvider)
        ? { handleDelete(task) } : nil
    )
    .contextMenu { completedTaskContextMenu(for: task) }
  }

  /// Context menu items shown on secondary-click (right-click or ctrl+click) of an active task row or card.
  @ViewBuilder
  private func taskContextMenu(for task: TaskItem) -> some View {
    Button {
      select(task)
    } label: {
      Label(TaskLabel.Menu.trackTask, systemImage: "timer")
    }
    Divider()
    if registry.closableProvider(for: task.id) != nil {
      Button {
        handleComplete(task)
      } label: {
        Label(TaskLabel.Menu.markAsCompleted, systemImage: "checkmark.circle.fill")
      }
    }
  }

  /// Context menu items shown on secondary-click of a completed task row or card.
  @ViewBuilder
  private func completedTaskContextMenu(for task: TaskItem) -> some View {
    if registry.closableProvider(for: task.id) != nil {
      Button {
        handleRestore(task)
      } label: {
        Label(TaskLabel.Menu.restoreTask, systemImage: "arrow.counterclockwise")
      }
    }
    if registry.provider(for: task.id) is (any WritableTaskProvider) {
      Button(role: .destructive) {
        handleDelete(task)
      } label: {
        Label(TaskLabel.Menu.deletePermanently, systemImage: "trash")
      }
    }
  }

  // MARK: - Grid layout

  private var taskGrid: some View {
    let columns = [GridItem(.adaptive(minimum: 180), spacing: 10)]
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let info = affordanceInfo {
          HStack(spacing: 6) {
            Image(systemName: info.icon).foregroundStyle(Color.accentColor)
            Text(info.label).foregroundStyle(.secondary)
            Spacer()
          }
          .padding(.horizontal, 2)
        }

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
            if affordanceInfo?.label != section.header {
              Text(section.header).font(.subheadline).fontWeight(.semibold).padding(.horizontal, 2)
            }

            LazyVGrid(columns: columns, spacing: 10) {
              ForEach(section.tasks) { task in
                Button {
                  select(task)
                } label: {
                  TaskCardView(task: task, onComplete: onCompleteHandler(for: task))
                }
                .buttonStyle(.plain)
                .contextMenu { taskContextMenu(for: task) }
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
      sortBy: settings.taskSortField, direction: settings.taskSortDirection)
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
    selectedTab = .timer
  }

  private func onCompleteHandler(for task: TaskItem) -> (() -> Void)? {
    registry.closableProvider(for: task.id) != nil ? { self.handleComplete(task) } : nil
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
    selectedTab: .constant(.tasks),
    settings: AppSettings()
  )
}
