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
  var nav: MainNavigation
  @Bindable var settings: AppSettings

  @State private var query: String = ""
  @State private var sections: [TaskSection] = []
  @State private var isLoading: Bool = false
  @State private var isAddingTask = false
  @State private var isEditingTask = false
  @State private var taskToEdit: TaskItem?
  @State private var showCompleted = false
  @State private var completedTasks: [TaskItem] = []
  @State private var isLoadingCompleted = false

  /// Returns the writable provider for the current sidebar selection, or the first
  /// enabled writable provider when the selection is `.today` or unresolved.
  private var writableProvider: (any WritableTaskProvider)? {
    guard case .list(let sel) = registry.selection,
      let provider = registry.providers.first(where: {
        $0.id == sel.providerID && registry.isEnabled($0.id)
      }),
      let writable = provider as? (any WritableTaskProvider)
    else { return registry.firstEnabledWritableProvider }
    return writable
  }

  private var hasClosableProvider: Bool {
    registry.providers.contains { registry.isEnabled($0.id) && $0 is (any ClosableTaskProvider) }
  }

  private var totalCompletedCount: Int { completedTasks.count }

  /// The icon and label describing the user's current navigational position (list, Today, or search).
  private var navigationContext: (icon: String, label: String)? {
    if !query.isEmpty {
      let count = sections.reduce(0) { $0 + $1.tasks.count }
      let label = isLoading ? "Searching…" : "\(count) \(count == 1 ? "result" : "results")"
      return ("magnifyingglass", label)
    }
    if registry.selection == .today { return ("calendar", "Today") }
    guard case .list(let sel) = registry.selection,
      let listName = registry.providerLists[sel.providerID]?
        .first(where: { $0.id == sel.listID })?.name
    else { return nil }
    let icon = registry.providers.first(where: { $0.id == sel.providerID })?.icon ?? "list.bullet"
    return (icon, listName)
  }

  var body: some View {
    NavigationSplitView(
      columnVisibility: Binding(
        get: { nav.sidebarVisible ? .all : .detailOnly },
        set: { nav.sidebarVisible = $0 != .detailOnly }
      )
    ) {
      ProviderSidebarView(registry: registry, onTaskAdded: { Task { await refresh() } })
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
    } detail: {
      detailColumn
    }
    .searchable(text: $query, placement: .toolbar, prompt: "Search tasks")
    .task(id: query) { await refresh() }
    .task { await subscribeToProviderUpdates() }
    .onAppear { Task { await refresh() } }
    .onChange(of: isAddingTask) { _, adding in
      if !adding { Task { await refresh() } }
    }
    .onChange(of: isEditingTask) { _, editing in
      if !editing { Task { await refresh() } }
    }
    .onChange(of: registry.enabledIDs) { _, _ in Task { await refresh() } }
    .onChange(of: registry.selection) { _, _ in
      query = ""
      Task { await refresh() }
    }
    .onChange(of: registry.providerLists) { _, _ in Task { await refresh() } }
    .onChange(of: settings.taskSortField) { _, _ in Task { await refresh() } }
    .onChange(of: settings.taskSortDirection) { _, _ in Task { await refresh() } }
    .onChange(of: registry.providerAuthorizationStates) { _, _ in
      Task { await refresh() }
    }
    .sheet(isPresented: $isAddingTask) {
      if let provider = writableProvider {
        AddTaskView(provider: provider, isPresented: $isAddingTask)
      }
    }
    .sheet(isPresented: $isEditingTask) {
      if let task = taskToEdit, let provider = registry.writableProvider(for: task.id) {
        AddTaskView(provider: provider, isPresented: $isEditingTask, taskToEdit: task)
      }
    }
    .toolbar {
      if writableProvider != nil {
        ToolbarItem(placement: .automatic) {
          Button {
            isAddingTask = true
          } label: {
            Label("Add Task", systemImage: "plus")
          }
          .help("Add a task")
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
  private var detailColumn: some View {
    VStack(spacing: 0) {
      if let info = navigationContext {
        HStack(spacing: 6) {
          Image(systemName: info.icon).foregroundStyle(Color.accentColor)
          Text(info.label).foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
      detailContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

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
    } else if sections.isEmpty && (!showCompleted || completedTasks.isEmpty) {
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
      SwiftUI.ForEach(sections) { section in
        listSection(for: section)
      }

      if showCompleted && !completedTasks.isEmpty {
        SwiftUI.Section {
          SwiftUI.ForEach(completedTasks) { task in completedRow(task) }
        } header: {
          completedSectionHeader
        }
      }
    }
  }

  @ViewBuilder
  private func listSection(for section: TaskSection) -> some View {
    SwiftUI.Section {
      SwiftUI.ForEach(section.tasks) { task in
        Button {
          select(task)
        } label: {
          TaskRowView(
            task: task,
            kind: .active(onComplete: onCompleteHandler(for: task)),
            lineage: lineage(for: task)
          )
        }
        .buttonStyle(.plain)
        .contextMenu { taskContextMenu(for: task) }
      }
    } header: {
      if shouldShowHeader(section) {
        Text(section.header).font(.subheadline).fontWeight(.semibold)
      }
    }
  }

  /// Context menu items shown on secondary-click (right-click or ctrl+click) of an active task row or card.
  @ViewBuilder
  private func taskContextMenu(for task: TaskItem) -> some View {
    Button {
      select(task)
    } label: {
      Label(TaskLabel.Menu.trackTask, systemImage: "timer")
    }
    if registry.writableProvider(for: task.id) != nil {
      Button {
        taskToEdit = task
        isEditingTask = true
      } label: {
        Label("Edit…", systemImage: "pencil")
      }
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
        ForEach(sections) { section in
          VStack(alignment: .leading, spacing: 8) {
            if shouldShowHeader(section) {
              Text(section.header)
                .font(.subheadline).fontWeight(.semibold).padding(.horizontal, 2)
            }

            LazyVGrid(columns: columns, spacing: 10) {
              ForEach(section.tasks) { task in
                Button {
                  select(task)
                } label: {
                  TaskCardView(
                    task: task,
                    kind: .active(onComplete: onCompleteHandler(for: task)),
                    lineage: lineage(for: task)
                  )
                }
                .buttonStyle(.plain)
                .contextMenu { taskContextMenu(for: task) }
              }
            }

          }
        }

        if showCompleted && !completedTasks.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            completedSectionHeader
              .padding(.horizontal, 2)
            LazyVGrid(columns: columns, spacing: 10) {
              ForEach(completedTasks) { task in completedCard(task) }
            }
          }
        }
      }
      .padding(10)
    }
  }

  @ViewBuilder
  private var completedSectionHeader: some View {
    HStack {
      Text("\(completedTasks.count) Completed")
        .font(.subheadline).fontWeight(.semibold)
      Spacer()
      Button("Hide") { showCompleted = false }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
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
            await refresh()
          }
        }
      }
    }
  }

  private var currentQuery: TaskQuery {
    if !query.isEmpty { return .crossProvider(filter: .titleContains(query)) }
    if case .list(let sel) = registry.selection { return .singleList(sel) }
    return .crossProvider(filter: .dueUpToToday)
  }

  private func loadTasks() async {
    guard !query.isEmpty || registry.selection != nil else {
      sections = []
      return
    }
    isLoading = sections.isEmpty
    let (tasks, _) = await registry.tasks(
      query: currentQuery,
      sortBy: settings.taskSortField, direction: settings.taskSortDirection)
    sections = buildDisplaySections(from: tasks, query: currentQuery)
    isLoading = false
  }

  private func refresh() async {
    await loadTasks()
    if showCompleted { await loadCompleted() }
  }

  private func loadCompleted() async {
    isLoadingCompleted = true
    let (tasks, _) = await registry.completedTasks(
      query: currentQuery,
      sortBy: settings.taskSortField,
      direction: settings.taskSortDirection
    )
    completedTasks = tasks
    isLoadingCompleted = false
  }

  /// Builds a ``TaskLineage`` for flat-mode task rows and cards.
  private func lineage(for task: TaskItem) -> TaskLineage? {
    guard currentQuery.isCrossProvider else { return nil }
    let showIcon = registry.enabledIDs.count > 1
    let provider = registry.providers.first { $0.id == task.id.providerID }
    let lin = TaskLineage(
      providerIcon: showIcon ? provider?.icon : nil,
      listName: task.list?.name,
      sectionName: task.section
    )
    return lin.isEmpty ? nil : lin
  }

  private func completedKind(for task: TaskItem) -> TaskItemKind {
    let canDelete = registry.provider(for: task.id) is (any WritableTaskProvider)
    return .completed(
      onRestore: { handleRestore(task) },
      onDelete: canDelete ? { handleDelete(task) } : nil
    )
  }

  /// A ``TaskRowView`` wired to this view's restore and delete handlers.
  private func completedRow(_ task: TaskItem) -> some View {
    TaskRowView(task: task, kind: completedKind(for: task), lineage: lineage(for: task))
      .contextMenu { completedTaskContextMenu(for: task) }
  }

  /// A ``TaskCardView`` wired to this view's restore and delete handlers.
  private func completedCard(_ task: TaskItem) -> some View {
    TaskCardView(task: task, kind: completedKind(for: task), lineage: lineage(for: task))
      .contextMenu { completedTaskContextMenu(for: task) }
  }

  private func shouldShowHeader(_ section: TaskSection) -> Bool {
    section.displayStyle == .sectioned
      && !section.header.isEmpty
      && navigationContext?.label != section.header
  }

  private func select(_ task: TaskItem) {
    selectionStore.select(task)
    nav.showTimer()
  }

  private func onCompleteHandler(for task: TaskItem) -> (() -> Void)? {
    registry.closableProvider(for: task.id) != nil ? { self.handleComplete(task) } : nil
  }

  private func handleComplete(_ task: TaskItem) {
    Task {
      if let provider = registry.closableProvider(for: task.id) {
        try? await provider.complete(task.id)
      }
      await refresh()
    }
  }

  private func handleRestore(_ task: TaskItem) {
    Task {
      if let provider = registry.closableProvider(for: task.id) {
        try? await provider.reopen(task.id)
      }
      await refresh()
    }
  }

  private func handleDelete(_ task: TaskItem) {
    Task {
      if let provider = registry.provider(for: task.id) as? (any WritableTaskProvider) {
        try? await provider.deleteTask(task.id)
      }
      await loadCompleted()
    }
  }

}

#Preview {
  TasksTabView(
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    nav: MainNavigation(settings: AppSettings()),
    settings: AppSettings()
  )
}
