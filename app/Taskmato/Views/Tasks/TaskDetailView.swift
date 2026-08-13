//
//  TaskDetailView.swift
//  Taskmato
//

import AppKit
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
  /// Not `private`: `TaskDetailSelection.swift` resolves ``selection`` against this.
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
  /// Incremented to ask the AppKit task-content responder to reclaim first-responder status.
  @State var taskContentFocusToken = 0
  /// Whether task content owns keyboard focus, driving active versus inactive selection color.
  @State var isTaskContentFocused = false
  /// The single selected task (issue #546) — ephemeral, view-local, and independent of
  /// ``TaskSelectionStore``'s active/tracked task. Drives the clipboard and `.onDeleteCommand`;
  /// cleared whenever the sidebar selection changes. Not `private`: `handleDelete(_:)` in
  /// `TaskDetailActions.swift` clears it when the selected task is removed.
  @State var selection: TaskRef?
  /// The selected task pending permanent deletion via `.onDeleteCommand`, driving the confirmation
  /// dialog. Not `private`: managed from `TaskDetailSelection.swift`.
  @State var activeDeleteCandidate: TaskItem?

  /// Maps between clipboard payloads/plain text and ``TaskDraft``, and answers cut/delete/paste
  /// enablement (issue #546). Stateless, so a single instance is shared by both layouts. Not
  /// `private`: `TaskDetailActions.swift`'s `copyToPasteboard(_:to:)` builds payloads with it.
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
        // New Task is the primary creation action, so it stays its own leading item — visually
        // distinct from the view-state controls that follow.
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

        // Show/Hide Completed stays adjacent to Layout and Sort — all three are task-view
        // controls — while Layout and Sort are grouped together as one toolbar unit since both
        // alter task-list presentation.
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
        selection = nil
        isTaskContentFocused = false
        Task { await refresh() }
      }
      .onChange(of: selection) { _, newSelection in
        // Native List selection changes after the table handles the click. Reclaim first
        // responder status after that handoff so Return and task commands keep working.
        if newSelection != nil { focusTaskContent() }
      }
      .onChange(of: isSearchFocused) { _, focused in
        if focused { isTaskContentFocused = false }
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
    attachActiveDeleteConfirmation(
      to:
        attachClipboardModifiers(
          to:
            attachTaskKeyboardResponder(
              to:
                List(selection: $selection) {
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
                .onTableDoubleClick { _ = activateSelection() }
                .contentShape(Rectangle())
                .onTapGesture { focusTaskContent() }
            )
        )
    )
  }

  @ViewBuilder
  private func listSection(for section: TaskSection) -> some View {
    SwiftUI.Section {
      SwiftUI.ForEach(section.tasks) { task in
        TaskRowView(
          task: task,
          kind: activeKind(for: task),
          lineage: lineage(for: task)
        )
        .tag(task.id)
        .listRowBackground(selectionBackground(for: task))
        .accessibilityAddTraits(selection == task.id ? .isSelected : [])
        .contextMenu { taskContextMenu(for: task) }
      }
    } header: {
      if shouldShowHeader(section) {
        Text(section.header).font(.sectionHeader)
      }
    }
  }

  // MARK: - Grid layout

  private var taskGrid: some View {
    let columns = [GridItem(.adaptive(minimum: 180), spacing: .groupGap)]
    return attachActiveDeleteConfirmation(
      to:
        attachClipboardModifiers(
          to:
            attachTaskKeyboardResponder(
              to:
                ScrollView {
                  VStack(alignment: .leading, spacing: .sectionGap) {
                    ForEach(sections) { section in
                      VStack(alignment: .leading, spacing: .contentGap) {
                        if shouldShowHeader(section) {
                          Text(section.header)
                            .font(.sectionHeader).padding(.horizontal, .stackTight)
                        }

                        LazyVGrid(columns: columns, spacing: .groupGap) {
                          ForEach(section.tasks) { task in
                            TaskCardView(
                              task: task,
                              kind: activeKind(for: task),
                              lineage: lineage(for: task),
                              isSelected: selection == task.id,
                              isSelectionFocused: isTaskContentFocused
                            )
                            .contentShape(RoundedRectangle.card)
                            .onTapGesture {
                              selection = task.id
                              focusTaskContent()
                            }
                            .simultaneousGesture(TapGesture(count: 2).onEnded { select(task) })
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
                .contentShape(Rectangle())
                .onTapGesture { focusTaskContent() }
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
  /// surfacing the same delete now reachable via the keyboard.
  private func activeKind(for task: TaskItem) -> TaskItemKind {
    let canDelete = registry.writableProvider(for: task.id) != nil
    return .active(
      onComplete: onCompleteHandler(for: task),
      onDelete: canDelete ? { handleDelete(task) } : nil
    )
  }

  private func shouldShowHeader(_ section: TaskSection) -> Bool {
    section.displayStyle == .sectioned
      && !section.header.isEmpty
      && navigationContext?.label != section.header
  }

  /// Activates `task`: makes it the active/tracked task and switches to the Timer tab.
  ///
  /// This is the "activate" gesture (issue #546) — double-click, Return with a selection, or
  /// the context-menu "Track Task" item — kept distinct from ``selection``, which only
  /// highlights a row for the clipboard and never navigates. Not `private`:
  /// `TaskDetailSelection.swift`'s `activateSelection()` calls this for Return.
  func select(_ task: TaskItem) {
    selectionStore.select(task)
    nav.showTimer()
  }

  /// Selects `task`, sets the focus length to `minutes`, and starts a session on it — the
  /// "Start Focus ▸" submenu's one-gesture action (design doc 0009, D7). Only reachable while
  /// `presenter.isIdle` (the submenu is disabled otherwise), so this never interrupts a
  /// running or paused session. Not `private`: called from `TaskDetailContextMenu.swift`'s
  /// "Start Focus ▸" submenu.
  func startFocus(_ task: TaskItem, minutes: Int) {
    selectionStore.select(task)
    settings.focusMinutes = minutes
    presenter.start()
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
    let selectionStore = SelectionStore(registry: registry)
    TaskDetailView(
      selectionStore: TaskSelectionStore(),
      registry: registry,
      queryService: TaskQueryService(registry: registry, sorter: TaskSorter()),
      destinationResolver: TaskDestinationResolver(registry: registry, settings: settings),
      sidebarSelection: selectionStore,
      nav: MainNavigation(
        settings: settings, selectionStore: selectionStore, statsViewModel: .preview),
      settings: settings,
      errorPresenter: ErrorPresenter(),
      presenter: TimerPresenter(engine: SessionEngine(), settings: settings)
    )
  }
#endif
