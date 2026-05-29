//
//  TasksTabView.swift
//  Taskmato
//

import SwiftUI

/// The task picker tab, showing tasks grouped into sections with live search.
///
/// Selecting a task sets it as the active task and switches to the Timer tab.
/// Section headers are formatted as "List: Section" when multiple lists are active,
/// or just "Section" when only one list is active. Supports toggling between a list
/// and an adaptive card grid layout.
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

  /// The local provider instance looked up from the registry, if registered.
  private var localProvider: LocalProvider? {
    registry.providers.first(where: { $0 is LocalProvider }) as? LocalProvider
  }

  /// `true` when the local provider is registered and currently enabled.
  private var localProviderEnabled: Bool {
    localProvider.map { registry.isEnabled($0.id) } ?? false
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
        return FlatSection(id: "\(group.id).\(section.id)", header: header, tasks: section.tasks)
      }
    }
  }

  var body: some View {
    Group {
      if registry.providers.filter({ registry.isEnabled($0.id) }).isEmpty {
        ContentUnavailableView(
          "No Task Providers",
          systemImage: "tray",
          description: Text("Enable a task provider in Settings to see your tasks here.")
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
    .searchable(text: $query, prompt: "Search tasks")
    .task(id: query) { await loadTasks() }
    .task { await subscribeToProviderUpdates() }
    .onAppear { Task { await loadTasks() } }
    .onChange(of: isAddingTask) { _, adding in
      if !adding { Task { await loadTasks() } }
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

  // MARK: - List layout

  private var taskList: some View {
    List {
      SwiftUI.ForEach(flatSections) { section in
        listSection(for: section)
      }
    }
  }

  @ViewBuilder
  private func listSection(for section: FlatSection) -> some View {
    SwiftUI.Section {
      SwiftUI.ForEach(section.tasks) { task in
        TaskRowView(
          task: task,
          onComplete: registry.mutableProvider(for: task.id) != nil
            ? { handleComplete(task) }
            : nil
        )
        .onTapGesture { select(task) }
      }
    } header: {
      Text(section.header)
        .font(.subheadline)
        .fontWeight(.semibold)
    }
  }

  // MARK: - Grid layout

  private var taskGrid: some View {
    let columns = [GridItem(.adaptive(minimum: 180), spacing: 10)]
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ForEach(flatSections) { section in
          VStack(alignment: .leading, spacing: 8) {
            Text(section.header)
              .font(.subheadline)
              .fontWeight(.semibold)
              .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: 10) {
              ForEach(section.tasks) { task in
                TaskCardView(
                  task: task,
                  onComplete: registry.mutableProvider(for: task.id) != nil
                    ? { handleComplete(task) }
                    : nil
                )
                .onTapGesture { select(task) }
              }
            }
          }
        }
      }
      .padding(10)
    }
  }

  // MARK: - Data loading

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
    let (tasks, _) = await registry.tasks(matching: query)
    groupedLists = buildGroups(from: tasks)
    isLoading = false
  }

  private func select(_ task: TaskItem) {
    selectionStore.select(task)
    selectedTab = 0
  }

  /// Completes the task via its mutable provider, then refreshes the list.
  private func handleComplete(_ task: TaskItem) {
    let ref = task.id
    Task {
      if let provider = registry.mutableProvider(for: ref) {
        try? await provider.complete(ref)
      }
      await loadTasks()
    }
  }

  // MARK: - Grouping

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

// MARK: - Supporting types

/// A grouped collection of tasks sharing a ``TaskList``.
private struct TaskGroup: Identifiable {
  let id: String
  let listName: String
  let sections: [TaskSection]
}

/// A collection of tasks under a single section heading within a list.
private struct TaskSection: Identifiable {
  let id: String
  let name: String?
  let tasks: [TaskItem]
}

/// A flattened display section with a computed header label and its tasks.
private struct FlatSection: Identifiable {
  let id: String
  let header: String
  let tasks: [TaskItem]
}

#Preview {
  TasksTabView(
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    selectedTab: .constant(1),
    settings: AppSettings()
  )
}
