//
//  TaskDetailView.swift
//  Taskmato
//

import AppKit
import SwiftUI

/// The task detail surface for the Today and list destinations of the window-first shell.
///
/// Renders the current task-scope selection (``SelectionStore``) as a grouped list with live
/// search, an add/show-completed/sort toolbar, and per-task context menus.
/// It is placed in the root ``NavigationSplitView``'s detail column by ``MainWindowView``; the
/// universal sidebar and column visibility live in the shell, not here. When at least one
/// enabled provider conforms to ``ClosableTaskProvider``, a "Show Completed" toolbar button
/// becomes available.
struct TaskDetailView: View {

  var activeTaskStore: ActiveTaskStore
  var registry: ProviderRegistry
  var queryService: TaskQueryService
  var destinationResolver: TaskDestinationResolver
  var sidebarSelection: SelectionStore
  var nav: MainNavigation
  @Bindable var settings: AppSettings
  var errorPresenter: ErrorPresenter
  /// Drives the "Start Focus ▸" context-menu submenu (design doc 0009, D7): its preset list,
  /// idle state, and the start intent.
  var presenter: TimerPresenter
  /// Bumped by the sidebar after adding a task, so the detail reloads the affected list.
  var refreshToken: Int = 0

  /// Opens a task's provider deep link, matching what ``TaskSourceBadge`` does via `Link`. Not
  /// `private`: `TaskDetailSelection.swift`'s `openInProvider(_:)` calls this.
  @Environment(\.openURL) var openURL

  @State private var query: String = ""
  /// Not `private`: `TaskDetailSelection.swift` resolves ``selectedTaskID`` against this.
  @State var sections: [TaskSection] = []
  @State private var isLoading: Bool = false
  @State private var isAddingTask = false
  @State private var newTaskDestination: TaskDestination?
  /// Not `private`: `TaskDetailContextMenu.swift`'s "Edit…" item sets this.
  @State var isEditingTask = false
  /// Not `private`: `TaskDetailContextMenu.swift`'s "Edit…" item sets this.
  @State var taskToEdit: TaskItem?
  /// Whether the completed-task section is visible. Not `private`: grid selection navigation in
  /// `TaskDetailSelection.swift` includes completed tasks when this is true.
  @State var showCompleted = false
  /// Loaded completed tasks for the current query. Not `private`: selection resolution searches
  /// these tasks so completed rows/cards support copy, cut, and delete.
  @State var completedTasks: [TaskItem] = []
  @State private var isLoadingCompleted = false
  @FocusState private var isSearchFocused: Bool
  /// The single selected task (issue #546) — ephemeral, view-local, and independent of
  /// ``ActiveTaskStore``'s active/tracked task. Drives the clipboard and `.onDeleteCommand`;
  /// cleared whenever the sidebar selection changes. Not `private`: `handleDelete(_:)` in
  /// `TaskDetailActions.swift` clears it when the selected task is removed.
  @State var selectedTaskID: TaskRef?
  /// The selected task pending permanent deletion via `.onDeleteCommand`, driving the confirmation
  /// dialog. Not `private`: managed from `TaskDetailSelection.swift`.
  @State var activeDeleteCandidate: TaskItem?

  /// Maps between clipboard payloads/plain text and ``TaskDraft``, and answers cut/delete/paste
  /// enablement (issue #546). Not `private`: `TaskDetailActions.swift`'s
  /// `copyToPasteboard(_:to:)` builds payloads with it.
  let clipboardService = TaskClipboardService()

  /// Returns the writable provider for the current sidebar selection using the shared resolver.
  /// Not `private`: `TaskDetailSelection.swift` uses this to resolve the paste target.
  var writableProvider: (any WritableTaskProvider)? {
    destinationResolver.provider(sidebarSelection: sidebarSelection.selection)
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
    attachOpenInProviderFocusedValues(to: detailWithCommands)
  }

  /// `trackedDetail` plus sheets, toolbar, and the focused-scene values every command menu
  /// besides Open in Provider reads. Split out so ``body`` can attach Open in Provider's
  /// focused-scene values as a separate, smaller expression (see
  /// ``attachOpenInProviderFocusedValues(to:)``).
  private var detailWithCommands: some View {
    trackedDetail
      .sheet(isPresented: $isAddingTask) {
        if let provider = writableProvider {
          AddTaskView(
            provider: provider, destinationResolver: destinationResolver,
            isPresented: $isAddingTask, errorPresenter: errorPresenter,
            initialListID: newTaskDestination?.listID)
        }
      }
      .sheet(isPresented: $isEditingTask) {
        if let task = taskToEdit, let provider = registry.writableProvider(for: task.id) {
          AddTaskView(
            provider: provider, destinationResolver: destinationResolver,
            isPresented: $isEditingTask, errorPresenter: errorPresenter, taskToEdit: task)
        }
      }
      .toolbar {
        // Track Task leads the toolbar: it is the primary action on a task the user has already
        // picked, and the pointer-driven counterpart to Return and the context-menu item — the
        // only activation affordances, since double-click no longer tracks.
        ToolbarItem(placement: .automatic) {
          Button {
            trackSelectionAction()?()
          } label: {
            Label(AppLabels.Task.track.title, systemImage: AppLabels.Task.track.systemImage)
          }
          .help(AppLabels.Tooltip.trackTask)
          .disabled(trackSelectionAction() == nil)
        }

        // New Task is the primary creation action, so it keeps its own item — visually distinct
        // from the view-state controls that follow.
        if writableProvider != nil {
          ToolbarItem(placement: .automatic) {
            Button {
              Task { await prepareNewTask() }
            } label: {
              Label(AppLabels.Task.add.title, systemImage: AppLabels.Task.add.systemImage)
            }
            .help(AppLabels.Tooltip.addTask)
          }
        }

        // Show/Hide Completed stays adjacent to Sort — both are task-view controls.
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

        ToolbarItemGroup(placement: .automatic) {
          sortMenu
        }

      }
      .focusedSceneValue(\.taskViewActive, true)
      .focusedSceneValue(\.focusSearch, { isSearchFocused = true })
      .focusedSceneValue(
        \.addTask,
        writableProvider != nil ? { Task { await prepareNewTask() } } : nil
      )
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

  private func prepareNewTask() async {
    do {
      newTaskDestination = try await destinationResolver.resolve(
        sidebarSelection: sidebarSelection.selection)
      isAddingTask = true
    } catch {
      errorPresenter.present(title: AppLabels.Error.addFailed, error: error)
    }
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
      .onAppear {
        Task { await refresh() }
      }
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
        selectedTaskID = nil
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
    } else {
      taskList
    }
  }

  // MARK: - List layout

  private var taskList: some View {
    attachActiveDeleteConfirmation(
      to:
        attachClipboardModifiers(
          to:
            attachTaskCommands(
              to:
                List(selection: $selectedTaskID) {
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
                // Inset style owns selection shape and accent, context-menu targeting,
                // focused/unfocused appearance, and row geometry. Nothing is layered on top.
                .listStyle(.inset)
            )
        )
    )
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

  /// Reloads the active-task sections for the current selection/query, and the completed
  /// section too when it is shown. Split out to `internal` so the action handlers in
  /// `TaskDetailActions.swift` can call it after a mutation.
  func refresh() async {
    await loadTasks()
    if showCompleted { await loadCompleted() }
  }

  /// Loads the completed tasks for the current selection/query into `completedTasks`. `internal`
  /// for the same reason as ``refresh()``.
  func loadCompleted() async {
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
  func lineage(for task: TaskItem) -> TaskLineage? {
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

  func completedKind(for task: TaskItem) -> TaskItemKind {
    let canDelete = registry.provider(for: task.id) is (any WritableTaskProvider)
    return .completed(
      onRestore: { handleRestore(task) },
      onDelete: canDelete ? { handleDelete(task) } : nil
    )
  }

  /// The active-task kind wired to this view's complete and — for writable providers only —
  /// permanent-delete handlers. The trailing delete button reveals on hover (issue #546),
  /// surfacing the same delete now reachable via the keyboard. Not `private`:
  /// `TaskDetailCompletedViews.swift`'s `listSection(for:)` also calls this.
  func activeKind(for task: TaskItem) -> TaskItemKind {
    let canDelete = registry.writableProvider(for: task.id) != nil
    return .active(
      onComplete: onCompleteHandler(for: task),
      onDelete: canDelete ? { handleDelete(task) } : nil
    )
  }

  /// Whether `section`'s header should render. Not `private`:
  /// `TaskDetailCompletedViews.swift`'s `listSection(for:)` also calls this.
  func shouldShowHeader(_ section: TaskSection) -> Bool {
    section.displayStyle == .sectioned
      && !section.header.isEmpty
      && navigationContext?.label != section.header
  }

  /// Activates `task`: makes it the active/tracked task and switches to the Timer tab.
  ///
  /// This is the "activate" gesture (issue #546) — double-click, Return with a selection, or
  /// the context-menu "Track Task" item — kept distinct from ``selectedTaskID``, which only
  /// highlights a row for the clipboard and never navigates. Not `private`:
  /// `TaskDetailSelection.swift`'s `activateSelection()` calls this for Return.
  func track(_ task: TaskItem) {
    activeTaskStore.track(task)
    nav.showTimer()
  }

  /// Selects `task`, sets the focus length to `minutes`, and starts a session on it — the
  /// "Start Focus ▸" submenu's one-gesture action (design doc 0009, D7). Guarded on
  /// `presenter.canSelectFocusPreset` so the four start effects are all-or-nothing (issue #592).
  /// If the phase has moved off idle-focus-next since the submenu opened — e.g. a `taskmato://`
  /// URL raced ahead and started a session between the submenu opening and this click landing
  /// (issue #595) — this de-escalates to ``stageNextFocus(_:minutes:)`` so the click stages the
  /// task instead of being silently dropped. Not `private`: called from
  /// `TaskDetailContextMenu.swift`'s "Start Focus ▸" submenu.
  func startFocus(_ task: TaskItem, minutes: Int) {
    guard presenter.canSelectFocusPreset else {
      stageNextFocus(task, minutes: minutes)
      return
    }
    activeTaskStore.track(task)
    settings.focusMinutes = minutes
    presenter.start()
    nav.showTimer()
  }

  /// Stages `task` to become active at the next focus phase and sizes that phase to `minutes` —
  /// the "Focus Next ▸" variant of the same submenu, now reachable in every state except
  /// idle-with-focus-next (design doc "stage the next focus", D-a). Writes
  /// `settings.focusMinutes` directly and unconditionally, exactly as ``startFocus(_:minutes:)``
  /// does, since there is no separate staged-length state (D-b). Not `private`: called from
  /// `TaskDetailContextMenu.swift`.
  func stageNextFocus(_ task: TaskItem, minutes: Int) {
    activeTaskStore.stage(task)
    settings.focusMinutes = minutes
    nav.showTimer()
  }

  private func onCompleteHandler(for task: TaskItem) -> (() -> Void)? {
    registry.closableProvider(for: task.id) != nil ? { self.handleComplete(task) } : nil
  }

}

#if DEBUG
  #Preview {
    let registry = ProviderRegistry()
    let settings = AppSettings()
    let sidebarSelectionStore = SelectionStore(registry: registry)
    TaskDetailView(
      activeTaskStore: ActiveTaskStore(),
      registry: registry,
      queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
      destinationResolver: TaskDestinationResolver(registry: registry, settings: settings),
      sidebarSelection: sidebarSelectionStore,
      nav: MainNavigation(
        settings: settings, selectionStore: sidebarSelectionStore, statsViewModel: .preview),
      settings: settings,
      errorPresenter: ErrorPresenter(),
      presenter: TimerPresenter(engine: SessionEngine(), settings: settings)
    )
  }
#endif
