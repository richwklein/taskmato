//
//  AppSidebarView.swift
//  Taskmato
//

import SwiftUI

/// The universal sidebar — the window-first shell's entire navigation.
///
/// A single `List` bound to ``MainNavigation/destination`` holds every destination: the
/// pinned Timer and Today rows, one collapsible ``Section`` per enabled provider (list rows,
/// inline rename, star-default, and a "New list" row for writable providers), and a
/// collapsible Stats section of scope rows. Section expansion is persisted via
/// ``AppSettings/collapsedSidebarSections``; enabling or configuring a provider re-expands
/// its section. When no provider is enabled, the provider area is replaced by an add hint.
struct AppSidebarView: View {

  @Bindable var nav: MainNavigation
  var registry: ProviderRegistry
  var settings: AppSettings
  /// Called after a task is successfully added from the list context-menu "Add Task…" item.
  var onTaskAdded: (() -> Void)?

  /// Inline new-list name buffer keyed by provider ID.
  @State private var newListName: [String: String] = [:]

  /// The list ID currently being renamed inline, or `nil` when no rename is in progress.
  @State private var renamingListID: String?

  /// Editable buffer for the in-progress rename.
  @State private var renameBuffer: String = ""

  /// Drives focus into the rename `TextField` when a rename begins.
  @FocusState private var renameFocused: String?

  /// The provider whose configuration sheet is currently presented, or `nil`.
  @State private var configuringProvider: (any ConfigurableTaskProvider)?

  /// Provider and list targeted by the "Add Task…" context-menu action, or `nil`.
  @State private var addTaskTarget: AddTaskTarget?

  /// Drives the "Add Task…" sheet opened from the list context menu.
  @State private var isAddingTask = false

  // MARK: - Computed helpers

  private var enabledProviders: [any TaskProvider] {
    registry.providers.filter { registry.isEnabled($0.id) }
  }

  private var disabledProviders: [any TaskProvider] {
    registry.providers.filter { !registry.isEnabled($0.id) }
  }

  /// Section id used for the Stats section's persisted expansion state.
  private static let statsSectionID = "stats"

  // MARK: - Body

  var body: some View {
    List(selection: $nav.destination) {
      Label("Timer", systemImage: "timer")
        .tag(AppDestination.timer)
      Label("Today", systemImage: "calendar")
        .tag(AppDestination.today)

      if enabledProviders.isEmpty {
        emptyProvidersHint
      } else {
        ForEach(enabledProviders, id: \.id) { provider in
          providerSection(provider)
        }
      }

      statsSection
    }
    .listStyle(.sidebar)
    .contextMenu(forSelectionType: AppDestination.self) { selections in
      sidebarContextMenu(for: selections)
    }
    .task { await loadAllLists() }
    .onChange(of: registry.enabledIDs) { old, new in
      handleNewlyEnabled(new.subtracting(old))
    }
    .onChange(of: isAddingTask) { _, adding in
      if !adding { onTaskAdded?() }
    }
    .sheet(
      isPresented: Binding(
        get: { configuringProvider != nil },
        set: { if !$0 { configuringProvider = nil } }
      ),
      onDismiss: { Task { await loadAllLists() } },
      content: {
        if let provider = configuringProvider {
          provider.configurationView()
        }
      }
    )
    .sheet(isPresented: $isAddingTask) {
      if let target = addTaskTarget {
        AddTaskView(
          provider: target.provider,
          isPresented: $isAddingTask,
          initialListID: target.listID
        )
      }
    }
  }

  // MARK: - Empty state

  @ViewBuilder
  private var emptyProvidersHint: some View {
    VStack(spacing: .contentGap) {
      Text("No providers enabled")
        .font(.callout)
        .foregroundStyle(.secondary)
      addProviderMenu
        .fixedSize()
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, .sectionGap)
    .listRowSeparator(.hidden)
  }

  // MARK: - Provider section

  @ViewBuilder
  private func providerSection(_ provider: any TaskProvider) -> some View {
    Section(isExpanded: expansionBinding(for: provider.id)) {
      ForEach(lists(for: provider)) { list in
        listRow(list, provider: provider)
          .tag(AppDestination.list(SelectedList(providerID: provider.id, listID: list.id)))
      }
      if provider is (any WritableTaskProvider) {
        newListRow(providerID: provider.id)
      }
    } header: {
      HStack(spacing: .iconLabel) {
        Image(systemName: provider.icon)
          .imageScale(.small)
        Text(provider.displayName)
        Spacer()
      }
      .font(.callout)
      .padding(.vertical, .stackTight)
      .contentShape(Rectangle())
      .contextMenu {
        if let configurable = provider as? (any ConfigurableTaskProvider) {
          Button {
            configuringProvider = configurable
          } label: {
            Label(
              "Configure \(provider.displayName)…",
              systemImage: AppLabels.Sidebar.configure.systemImage)
          }
          Divider()
        }
        Button(role: .destructive) {
          registry.disable(providerID: provider.id)
        } label: {
          Label("Remove \(provider.displayName)", systemImage: AppLabels.Sidebar.remove.systemImage)
        }
      }
    }
  }

  // MARK: - Stats section

  @ViewBuilder
  private var statsSection: some View {
    Section(isExpanded: expansionBinding(for: Self.statsSectionID)) {
      ForEach(StatScope.allCases, id: \.self) { scope in
        Label(scope.sidebarLabel, systemImage: "chart.bar")
          .tag(AppDestination.stats(scope))
      }
    } header: {
      Text("Stats")
        .font(.callout)
        .padding(.vertical, .stackTight)
    }
  }

  // MARK: - List row

  @ViewBuilder
  private func listRow(_ list: TaskList, provider: any TaskProvider) -> some View {
    let writable = provider as? (any WritableTaskProvider)
    let isDefaultList = isDefault(list.id, for: provider)

    HStack(spacing: .iconLabel) {
      Image(systemName: "list.bullet")
        .imageScale(.small)
        .foregroundStyle(.secondary)

      listNameField(list: list, provider: provider)

      Spacer()

      if writable != nil {
        Button {
          let id = list.id
          Task { try? await writable?.setDefaultList(id) }
        } label: {
          Image(systemName: isDefaultList ? "star.fill" : "star")
            .imageScale(.small)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isDefaultList ? Color.favoriteStar : Color.secondary)
        .help(isDefaultList ? "Default list" : "Set as default list")
      }
    }
  }

  /// Builds the contextual menu for a control-clicked sidebar selection.
  ///
  /// Empty-area clicks (empty `selections`) surface the "Add Provider" menu; a control-click
  /// on a writable list row surfaces "Add Task…" plus the set/rename/delete actions. Timer,
  /// Today, Stats, and read-only rows produce no items.
  @ViewBuilder
  private func sidebarContextMenu(for selections: Set<AppDestination>) -> some View {
    if let resolved = resolveListAction(from: selections) {
      listContextMenu(for: resolved)
    } else if selections.isEmpty {
      addProviderMenuItems
    }
  }

  @ViewBuilder
  private func listContextMenu(for resolved: ListAction) -> some View {
    let list = resolved.list
    let provider = resolved.provider
    let writable = resolved.writable
    let isDefaultList = isDefault(list.id, for: provider)

    Button {
      addTaskTarget = AddTaskTarget(provider: writable, listID: list.id)
      isAddingTask = true
    } label: {
      Label(AppLabels.Sidebar.addTask.title, systemImage: AppLabels.Sidebar.addTask.systemImage)
    }

    Divider()

    Button {
      let id = list.id
      Task { try? await writable.setDefaultList(id) }
    } label: {
      Label(
        AppLabels.Sidebar.setDefault.title, systemImage: AppLabels.Sidebar.setDefault.systemImage)
    }
    .disabled(isDefaultList)

    Button {
      renamingListID = list.id
      renameBuffer = list.name
      renameFocused = list.id
    } label: {
      Label(AppLabels.Sidebar.rename.title, systemImage: AppLabels.Sidebar.rename.systemImage)
    }

    Divider()

    Button(role: .destructive) {
      Task {
        try? await writable.deleteList(list.id)
        await loadLists(for: provider)
      }
    } label: {
      Label(
        AppLabels.Sidebar.deleteList.title, systemImage: AppLabels.Sidebar.deleteList.systemImage)
    }
    .disabled(isDefaultList)
  }

  /// Resolves the row-targeted context-menu action from a selection set, or `nil` for non-writable rows.
  private func resolveListAction(from selections: Set<AppDestination>) -> ListAction? {
    guard let selection = selections.first,
      case .list(let selectedList) = selection,
      let provider = registry.providers.first(where: { $0.id == selectedList.providerID }),
      let writable = provider as? (any WritableTaskProvider),
      let list = lists(for: provider).first(where: { $0.id == selectedList.listID })
    else { return nil }
    return ListAction(list: list, provider: provider, writable: writable)
  }

  /// Tuple-like value that bundles the list, owning provider, and its writable interface
  /// resolved from a context-menu selection.
  private struct ListAction {
    let list: TaskList
    let provider: any TaskProvider
    let writable: any WritableTaskProvider
  }

  /// Provider and list ID targeted by the "Add Task…" context-menu sheet.
  private struct AddTaskTarget {
    let provider: any WritableTaskProvider
    let listID: String
  }

  /// Inline name display that switches to an editable `TextField` during a rename.
  @ViewBuilder
  private func listNameField(list: TaskList, provider: any TaskProvider) -> some View {
    if renamingListID == list.id {
      TextField("", text: $renameBuffer)
        .textFieldStyle(.plain)
        .focused($renameFocused, equals: list.id)
        .onSubmit { commitRename(list: list, provider: provider) }
        .onExitCommand { cancelRename() }
    } else {
      Text(list.name)
        .lineLimit(1)
    }
  }

  // MARK: - New list row

  @ViewBuilder
  private func newListRow(providerID: String) -> some View {
    let nameBinding = Binding(
      get: { newListName[providerID] ?? "" },
      set: { newListName[providerID] = $0 }
    )

    HStack(spacing: .iconLabel) {
      Image(systemName: "plus")
        .imageScale(.small)
        .foregroundStyle(.secondary)

      TextField("New list", text: nameBinding)
        .textFieldStyle(.plain)
        .onSubmit {
          let trimmed = (newListName[providerID] ?? "").trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return }
          guard
            let writable = registry.providers.first(where: { $0.id == providerID })
              as? (any WritableTaskProvider)
          else { return }
          newListName[providerID] = ""
          Task {
            _ = try? await writable.createList(name: trimmed)
            await loadLists(for: writable)
          }
        }
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Add Provider menu

  /// Menu items enabling any registered-but-disabled provider. Used by the empty-area
  /// context menu and the empty-state hint. Post-enable handling (expand, configure, load
  /// lists) runs in ``handleNewlyEnabled(_:)`` so it is uniform across every entry point,
  /// including the File → Add Provider command.
  @ViewBuilder
  private var addProviderMenuItems: some View {
    ForEach(disabledProviders, id: \.id) { provider in
      Button {
        registry.enable(provider)
      } label: {
        Label(provider.displayName, systemImage: provider.icon)
      }
    }
  }

  private var addProviderMenu: some View {
    Menu {
      addProviderMenuItems
    } label: {
      Label(
        AppLabels.Sidebar.addProvider.title, systemImage: AppLabels.Sidebar.addProvider.systemImage
      )
    }
    .menuStyle(.borderlessButton)
  }

  /// Reacts to providers becoming enabled from any source: re-expands each section, opens the
  /// configuration sheet for a configurable provider that is not yet authorized (so lists can
  /// load), and refreshes its list cache.
  private func handleNewlyEnabled(_ addedIDs: Set<String>) {
    guard !addedIDs.isEmpty else { return }
    let added = registry.providers.filter { addedIDs.contains($0.id) }
    for provider in added {
      settings.collapsedSidebarSections.remove(provider.id)
      if let configurable = provider as? (any ConfigurableTaskProvider), !provider.isAuthorized {
        configuringProvider = configurable
      }
    }
    Task {
      for provider in added {
        await loadLists(for: provider)
      }
    }
  }

  // MARK: - Expansion state

  /// A binding that maps a section's persisted collapsed state to `Section(isExpanded:)`.
  private func expansionBinding(for id: String) -> Binding<Bool> {
    Binding(
      get: { !settings.collapsedSidebarSections.contains(id) },
      set: { expanded in
        if expanded {
          settings.collapsedSidebarSections.remove(id)
        } else {
          settings.collapsedSidebarSections.insert(id)
        }
      }
    )
  }

  // MARK: - Data helpers

  private func lists(for provider: any TaskProvider) -> [TaskList] {
    registry.providerLists[provider.id] ?? []
  }

  private func isDefault(_ listID: String, for provider: any TaskProvider) -> Bool {
    (provider as? (any WritableTaskProvider))?.defaultListID == listID
  }

  // MARK: - Rename helpers

  private func commitRename(list: TaskList, provider: any TaskProvider) {
    let trimmed = renameBuffer.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, let writable = provider as? (any WritableTaskProvider) else {
      cancelRename()
      return
    }
    renamingListID = nil
    Task {
      try? await writable.renameList(list.id, name: trimmed)
      await loadLists(for: provider)
    }
  }

  private func cancelRename() {
    renamingListID = nil
    renameBuffer = ""
  }

  // MARK: - Async list loading

  private func loadAllLists() async {
    for provider in enabledProviders {
      await loadLists(for: provider)
    }
  }

  private func loadLists(for provider: any TaskProvider) async {
    let loaded = (try? await provider.lists()) ?? []
    registry.setLists(loaded, forProviderID: provider.id)
  }
}

#Preview {
  let registry = ProviderRegistry()
  let settings = AppSettings()
  let selectionStore = SelectionStore(registry: registry)
  return AppSidebarView(
    nav: MainNavigation(
      settings: settings, selectionStore: selectionStore, statsViewModel: .preview),
    registry: registry,
    settings: settings
  )
  .frame(width: 220, height: 500)
}
