//
//  TaskDetailView.swift
//  Taskmato
//

import SwiftUI

/// The task detail surface for the Today and list destinations of the window-first shell.
///
/// Renders the current task-scope selection (``SelectionStore``) as a grouped list or grid
/// with live search, an add/show-completed/layout/sort toolbar, and per-task context menus.
/// It is placed in the root ``NavigationSplitView``'s detail column by ``MainWindowView``; the
/// universal sidebar and column visibility live in the shell, not here. When at least one
/// enabled provider conforms to ``ClosableTaskProvider``, a "Show Completed" toolbar button
/// becomes available.
struct TaskDetailView: View {

  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var queryService: TaskQueryService
  var sidebarSelection: SelectionStore
  var nav: MainNavigation
  @Bindable var settings: AppSettings
  /// Bumped by the sidebar after adding a task, so the detail reloads the affected list.
  var refreshToken: Int = 0

  @State private var query: String = ""
  @State private var sections: [TaskSection] = []
  @State private var isLoading: Bool = false
  @State private var isAddingTask = false
  @State private var isEditingTask = false
  @State private var taskToEdit: TaskItem?
  @State private var showCompleted = false
  @State private var completedTasks: [TaskItem] = []
  @State private var isLoadingCompleted = false
  @FocusState private var isSearchFocused: Bool

  /// Returns the writable provider for the current sidebar selection, falling back to the
  /// default writable provider (from settings, then first enabled in registration order).
  private var writableProvider: (any WritableTaskProvider)? {
    guard case .list(let sel) = sidebarSelection.selection,
      let provider = registry.providers.first(where: {
        $0.id == sel.providerID && registry.isEnabled($0.id)
      }),
      let writable = provider as? (any WritableTaskProvider)
    else {
      return registry.resolveDefaultWritableProvider(
        preferredID: settings.defaultWritableProviderID)
    }
    return writable
  }

  private var hasClosableProvider: Bool {
    registry.providers.contains { registry.isEnabled($0.id) && $0 is (any ClosableTaskProvider) }
  }

  /// The label spec matching the current show/hide completed toolbar state.
  private var completedToggleSpec: AppLabel {
    showCompleted ? AppLabels.View.hideCompleted : AppLabels.View.showCompleted
  }

  private var totalCompletedCount: Int { completedTasks.count }

  /// The icon and label describing the user's current navigational position (list, Today, or search).
  private var navigationContext: (icon: String, label: String)? {
    if !query.isEmpty {
      let count = sections.reduce(0) { $0 + $1.tasks.count }
      let label = isLoading ? "Searching…" : "\(count) \(count == 1 ? "result" : "results")"
      return ("magnifyingglass", label)
    }
    if sidebarSelection.selection == .today { return ("calendar", "Today") }
    guard case .list(let sel) = sidebarSelection.selection,
      let listName = registry.providerLists[sel.providerID]?
        .first(where: { $0.id == sel.listID })?.name
    else { return nil }
    let icon = registry.providers.first(where: { $0.id == sel.providerID })?.icon ?? "list.bullet"
    return (icon, listName)
  }

  var body: some View {
    trackedDetail
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
              Label(AppLabels.Task.add.title, systemImage: AppLabels.Task.add.systemImage)
            }
            .help(AppLabels.Tooltip.addTask)
          }
        }

        if hasClosableProvider {
          ToolbarItem(placement: .automatic) {
            Button {
              showCompleted.toggle()
              if showCompleted { Task { await loadCompleted() } }
            } label: {
              let spec = showCompleted ? AppLabels.View.hideCompleted : AppLabels.View.showCompleted
              Label(spec.title, systemImage: spec.systemImage)
            }
            .help(showCompleted ? AppLabels.Tooltip.hideCompleted : AppLabels.Tooltip.showCompleted)
          }
        }

        ToolbarItem(placement: .automatic) {
          Picker("Layout", selection: $settings.taskPickerLayout) {
            Label(
              AppLabels.View.listLayout.title, systemImage: AppLabels.View.listLayout.systemImage
            )
            .tag(TaskPickerLayout.list)
            Label(
              AppLabels.View.gridLayout.title, systemImage: AppLabels.View.gridLayout.systemImage
            )
            .tag(TaskPickerLayout.grid)
          }
          .pickerStyle(.segmented)
          .help("Toggle between list and grid view")
        }

        ToolbarItem(placement: .automatic) {
          sortMenu
        }
      }
      .focusedSceneValue(\.focusSearch, { isSearchFocused = true })
      .focusedSceneValue(\.addTask, writableProvider != nil ? { isAddingTask = true } : nil)
      .focusedSceneValue(
        \.toggleCompleted,
        hasClosableProvider
          ? {
            showCompleted.toggle()
            if showCompleted { Task { await loadCompleted() } }
          } : nil
      )
      .focusedSceneValue(
        \.toggleCompletedTitle,
        hasClosableProvider ? completedToggleSpec.title : nil
      )
      .focusedSceneValue(
        \.toggleCompletedIcon,
        hasClosableProvider ? completedToggleSpec.systemImage : nil
      )
  }

  /// The detail content plus search and change-tracking modifiers.
  ///
  /// Split from ``body`` to keep each property's modifier chain short enough
  /// for the Swift type-checker.
  private var trackedDetail: some View {
    detailColumn
      .searchable(text: $query, placement: .toolbar, prompt: "Search tasks")
      .searchFocused($isSearchFocused)
      .task(id: query) { await refresh() }
      .task { await subscribeToProviderUpdates() }
      .onAppear { Task { await refresh() } }
      .onChange(of: refreshToken) { _, _ in Task { await refresh() } }
      .onChange(of: isAddingTask) { _, adding in
        if !adding { Task { await refresh() } }
      }
      .onChange(of: isEditingTask) { _, editing in
        if !editing { Task { await refresh() } }
      }
      .onChange(of: registry.enabledIDs) { _, _ in Task { await refresh() } }
      .onChange(of: sidebarSelection.selection) { _, _ in
        query = ""
        Task { await refresh() }
      }
      .onChange(of: registry.providerLists) { _, _ in Task { await refresh() } }
      .onChange(of: settings.taskSortField) { _, _ in Task { await refresh() } }
      .onChange(of: settings.taskSortDirection) { _, _ in Task { await refresh() } }
      .onChange(of: registry.providerAuthorizationStates) { _, _ in
        Task { await refresh() }
      }
  }

  // MARK: - Detail content

  @ViewBuilder
  private var detailColumn: some View {
    VStack(spacing: 0) {
      if let info = navigationContext {
        HStack(spacing: .iconLabel) {
          Image(systemName: info.icon).foregroundStyle(Color.accentColor)
          Text(info.label).foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.horizontal, .sectionGap)
        .padding(.vertical, .contentGap)
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
    } else if sidebarSelection.selection == nil {
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
      } else if sidebarSelection.selection == .today {
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
        Text(section.header).font(.sectionHeader)
      }
    }
  }

  /// Context menu items shown on secondary-click (right-click or ctrl+click) of an active task row or card.
  @ViewBuilder
  private func taskContextMenu(for task: TaskItem) -> some View {
    Button {
      select(task)
    } label: {
      Label(AppLabels.Task.track.title, systemImage: AppLabels.Task.track.systemImage)
    }
    if registry.writableProvider(for: task.id) != nil {
      Button {
        taskToEdit = task
        isEditingTask = true
      } label: {
        Label(AppLabels.Task.edit.title, systemImage: AppLabels.Task.edit.systemImage)
      }
    }
    Divider()
    if registry.closableProvider(for: task.id) != nil {
      Button {
        handleComplete(task)
      } label: {
        Label(AppLabels.Task.complete.title, systemImage: AppLabels.Task.complete.systemImage)
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
        Label(AppLabels.Task.restore.title, systemImage: AppLabels.Task.restore.systemImage)
      }
    }
    if registry.provider(for: task.id) is (any WritableTaskProvider) {
      Button(role: .destructive) {
        handleDelete(task)
      } label: {
        Label(AppLabels.Task.delete.title, systemImage: AppLabels.Task.delete.systemImage)
      }
    }
  }

  // MARK: - Grid layout

  private var taskGrid: some View {
    let columns = [GridItem(.adaptive(minimum: 180), spacing: .groupGap)]
    return ScrollView {
      VStack(alignment: .leading, spacing: .sectionGap) {
        ForEach(sections) { section in
          VStack(alignment: .leading, spacing: .contentGap) {
            if shouldShowHeader(section) {
              Text(section.header)
                .font(.sectionHeader).padding(.horizontal, .stackTight)
            }

            LazyVGrid(columns: columns, spacing: .groupGap) {
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
          VStack(alignment: .leading, spacing: .contentGap) {
            completedSectionHeader
              .padding(.horizontal, .stackTight)
            LazyVGrid(columns: columns, spacing: .groupGap) {
              ForEach(completedTasks) { task in completedCard(task) }
            }
          }
        }
      }
      .padding(.cardPadding)
    }
  }

  @ViewBuilder
  private var completedSectionHeader: some View {
    HStack {
      Text("\(completedTasks.count) Completed")
        .font(.sectionHeader)
      Spacer()
      Button("Hide") { showCompleted = false }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }
  }

}

// MARK: - Data loading

extension TaskDetailView {

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
    if case .list(let sel) = sidebarSelection.selection { return .singleList(sel) }
    return .crossProvider(filter: .dueUpToToday)
  }

  private func loadTasks() async {
    guard !query.isEmpty || sidebarSelection.selection != nil else {
      sections = []
      return
    }
    isLoading = sections.isEmpty
    let (tasks, _) = await queryService.tasks(
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
    let (tasks, _) = await queryService.completedTasks(
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
  let registry = ProviderRegistry()
  let settings = AppSettings()
  let selectionStore = SelectionStore(registry: registry)
  return TaskDetailView(
    selectionStore: TaskSelectionStore(),
    registry: registry,
    queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
    sidebarSelection: selectionStore,
    nav: MainNavigation(
      settings: settings, selectionStore: selectionStore, statsViewModel: .preview),
    settings: settings
  )
}
