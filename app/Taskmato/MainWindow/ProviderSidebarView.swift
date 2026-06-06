//
//  ProviderSidebarView.swift
//  Taskmato
//

import SwiftUI

/// Sidebar column for the Tasks tab.
///
/// Shows each enabled task provider as a collapsible ``Section``. Inside each section,
/// list rows carry a leading icon and, for writable providers, a star button to promote
/// the default list. Writable provider sections also expose an inline "New list" row at
/// the bottom. A context menu on each section header provides configure, rename, and
/// delete actions. The "Add Provider" menu at the bottom enables any registered but
/// currently disabled provider.
struct ProviderSidebarView: View {

  @Bindable var registry: TaskRegistry
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

  // MARK: - Body

  var body: some View {
    List(selection: $registry.selection) {
      Label("Today", systemImage: "calendar")
        .tag(SidebarSelection.today)

      ForEach(enabledProviders, id: \.id) { provider in
        providerSection(provider)
      }
    }
    .listStyle(.sidebar)
    .contextMenu(forSelectionType: SidebarSelection.self) { selections in
      listContextMenu(for: selections)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !disabledProviders.isEmpty {
        VStack(spacing: 0) {
          Divider()
          addProviderMenu
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
      }
    }
    .task { await loadAllLists() }
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

  // MARK: - Provider section

  @ViewBuilder
  private func providerSection(_ provider: any TaskProvider) -> some View {
    Section {
      ForEach(lists(for: provider)) { list in
        listRow(list, provider: provider)
          .tag(SidebarSelection.list(SelectedList(providerID: provider.id, listID: list.id)))
      }
      if provider is (any WritableTaskProvider) {
        newListRow(providerID: provider.id)
      }
    } header: {
      HStack(spacing: 6) {
        Image(systemName: provider.icon)
          .imageScale(.small)
        Text(provider.displayName)
        Spacer()
      }
      .font(.callout)
      .padding(.vertical, 2)
      .contentShape(Rectangle())
      .contextMenu {
        if let configurable = provider as? (any ConfigurableTaskProvider) {
          Button {
            configuringProvider = configurable
          } label: {
            Label("Configure \(provider.displayName)…", systemImage: "gear")
          }
          Divider()
        }
        Button(role: .destructive) {
          registry.disable(providerID: provider.id)
        } label: {
          Label("Remove \(provider.displayName)", systemImage: "trash")
        }
      }
    }
  }

  // MARK: - List row

  @ViewBuilder
  private func listRow(_ list: TaskList, provider: any TaskProvider) -> some View {
    let writable = provider as? (any WritableTaskProvider)
    let isDefaultList = isDefault(list.id, for: provider)

    HStack(spacing: 6) {
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
        .foregroundStyle(isDefaultList ? Color.yellow : Color.secondary)
        .help(isDefaultList ? "Default list" : "Set as default list")
      }
    }
  }

  /// Builds the contextual menu for a control-clicked sidebar selection.
  ///
  /// Activated via `contextMenu(forSelectionType:)` on the List, this looks up the
  /// writable list referenced by the clicked row and renders "Add Task…" plus the standard
  /// set/rename/delete management actions. Returns no items for `.today` or read-only rows.
  @ViewBuilder
  private func listContextMenu(for selections: Set<SidebarSelection>) -> some View {
    if let resolved = resolveListAction(from: selections) {
      let list = resolved.list
      let provider = resolved.provider
      let writable = resolved.writable
      let isDefaultList = isDefault(list.id, for: provider)

      Button {
        addTaskTarget = AddTaskTarget(provider: writable, listID: list.id)
        isAddingTask = true
      } label: {
        Label("Add Task…", systemImage: "plus.circle")
      }

      Divider()

      Button {
        let id = list.id
        Task { try? await writable.setDefaultList(id) }
      } label: {
        Label("Set as Default", systemImage: "star")
      }
      .disabled(isDefaultList)

      Button {
        renamingListID = list.id
        renameBuffer = list.name
        renameFocused = list.id
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      Divider()

      Button(role: .destructive) {
        Task {
          try? await writable.deleteList(list.id)
          await loadLists(for: provider)
        }
      } label: {
        Label("Delete", systemImage: "trash")
      }
      .disabled(isDefaultList)
    }
  }

  /// Resolves the row-targeted context-menu action from a selection set, or `nil` for non-writable rows.
  private func resolveListAction(from selections: Set<SidebarSelection>) -> ListAction? {
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

    HStack(spacing: 6) {
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
            try? await writable.createList(name: trimmed)
            await loadLists(for: writable)
          }
        }
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Add Provider menu

  private var addProviderMenu: some View {
    Menu {
      ForEach(disabledProviders, id: \.id) { provider in
        Button {
          registry.enable(provider)
          if let configurable = provider as? (any ConfigurableTaskProvider) {
            configuringProvider = configurable
          }
          Task { await loadLists(for: provider) }
        } label: {
          Label(provider.displayName, systemImage: provider.icon)
        }
      }
    } label: {
      Label("Add Provider", systemImage: "plus.circle")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .menuStyle(.borderlessButton)
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
  ProviderSidebarView(registry: TaskRegistry())
    .frame(width: 200, height: 400)
}
