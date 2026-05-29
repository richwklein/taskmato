//
//  ProviderSidebarView.swift
//  Taskmato
//

import SwiftUI

/// Sidebar column for the Tasks tab.
///
/// Shows each enabled task provider as a collapsible ``DisclosureGroup``. Inside
/// each group, list rows carry a checkbox to control visibility and, for writable
/// providers, a star button to promote the default list. Writable provider groups
/// also expose an inline "New list" row at the bottom. A context menu on each list
/// row provides set-default and delete actions. The "Add Provider" menu at the
/// bottom enables any registered but currently disabled provider.
struct ProviderSidebarView: View {

  var registry: TaskRegistry

  /// Lists loaded from non-local providers, keyed by provider ID.
  @State private var listsByProvider: [String: [TaskList]] = [:]

  /// Provider IDs whose ``DisclosureGroup`` is expanded (session-only; all start expanded).
  @State private var expanded: Set<String> = []

  /// Inline new-list name buffer keyed by provider ID.
  @State private var newListName: [String: String] = [:]

  /// Controls the Obsidian configuration sheet shown when Obsidian is first enabled.
  @State private var isConfiguringObsidian = false

  // MARK: - Computed helpers

  private var enabledProviders: [any TaskProvider] {
    registry.providers.filter { registry.isEnabled($0.id) }
  }

  private var disabledProviders: [any TaskProvider] {
    registry.providers.filter { !registry.isEnabled($0.id) }
  }

  /// Direct reference to the local provider for reactive access to its @Observable properties.
  private var localProvider: LocalProvider? {
    registry.providers.first(where: { $0 is LocalProvider }) as? LocalProvider
  }

  private var obsidianProvider: ObsidianProvider? {
    registry.providers.first(where: { $0 is ObsidianProvider }) as? ObsidianProvider
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      List {
        ForEach(enabledProviders, id: \.id) { provider in
          providerGroup(provider)
        }
      }
      .listStyle(.sidebar)

      if !disabledProviders.isEmpty {
        Divider()
        addProviderMenu
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
      }
    }
    .task { await loadAllLists() }
    .sheet(isPresented: $isConfiguringObsidian) {
      if let obsidian = obsidianProvider {
        obsidianSetupSheet(obsidian)
      }
    }
  }

  // MARK: - Provider group

  @ViewBuilder
  private func providerGroup(_ provider: any TaskProvider) -> some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { expanded.contains(provider.id) },
        set: { open in
          if open { expanded.insert(provider.id) } else { expanded.remove(provider.id) }
        }
      )
    ) {
      ForEach(lists(for: provider)) { list in
        listRow(list, provider: provider)
      }
      if provider is (any WritableTaskProvider) {
        newListRow(providerID: provider.id)
      }
    } label: {
      Text(provider.displayName)
        .font(.headline)
        .contextMenu {
          if provider is ObsidianProvider {
            Button("Configure Obsidian…") { isConfiguringObsidian = true }
            Divider()
          }
          Button("Remove \(provider.displayName)", role: .destructive) {
            registry.disable(providerID: provider.id)
          }
        }
    }
    .onAppear { expanded.insert(provider.id) }
  }

  // MARK: - List row

  @ViewBuilder
  private func listRow(_ list: TaskList, provider: any TaskProvider) -> some View {
    let writable = provider as? (any WritableTaskProvider)
    let isDefaultList = isDefault(list.id, for: provider)
    let allIDs = Set(lists(for: provider).map(\.id))

    HStack(spacing: 6) {
      Toggle(
        isOn: Binding(
          get: { registry.isListVisible(list.id, providerID: provider.id) },
          set: { visible in
            registry.setListVisible(
              list.id,
              providerID: provider.id,
              visible: visible,
              allListIDs: allIDs
            )
          }
        )
      ) {
        EmptyView()
      }
      .toggleStyle(.checkbox)
      .disabled(isDefaultList)

      Text(list.name)
        .lineLimit(1)

      Spacer()

      if writable != nil {
        Button {
          let id = list.id
          Task { try? await writable?.setDefaultList(id) }
        } label: {
          Image(systemName: isDefaultList ? "star.fill" : "star")
            .imageScale(.small)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDefaultList ? Color.yellow : Color.secondary)
        .help(isDefaultList ? "Default list" : "Set as default list")
      }
    }
    .contextMenu {
      if let writable {
        Button("Set as Default") {
          let id = list.id
          Task { try? await writable.setDefaultList(id) }
        }
        .disabled(isDefaultList)

        Divider()

        Button("Delete", role: .destructive) {
          let pid = provider.id
          Task {
            try? await writable.deleteList(list.id)
            await loadLists(for: provider)
            _ = pid
          }
        }
        .disabled(isDefaultList)
      }
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
        Button(provider.displayName) {
          registry.enable(provider)
          expanded.insert(provider.id)
          if provider is ObsidianProvider {
            isConfiguringObsidian = true
          }
          Task { await loadLists(for: provider) }
        }
      }
    } label: {
      Label("Add Provider", systemImage: "plus.circle")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .menuStyle(.borderlessButton)
  }

  // MARK: - Obsidian setup sheet

  @ViewBuilder
  private func obsidianSetupSheet(_ obsidian: ObsidianProvider) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Configure Obsidian")
        .font(.title2)
        .fontWeight(.semibold)

      ObsidianSettingsView(provider: obsidian)

      HStack {
        Spacer()
        Button("Done") { isConfiguringObsidian = false }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(minWidth: 360)
  }

  // MARK: - Data helpers

  /// Returns the lists to display for a provider.
  ///
  /// For ``LocalProvider``, reads `taskLists` directly so SwiftUI tracks the
  /// @Observable property and re-renders on mutations. Other providers use the
  /// async-loaded cache in `listsByProvider`.
  private func lists(for provider: any TaskProvider) -> [TaskList] {
    if let local = localProvider, provider.id == local.id {
      return local.taskLists.map(\.asTaskList)
    }
    return listsByProvider[provider.id] ?? []
  }

  /// Returns `true` when `listID` is the default list for `provider`.
  ///
  /// For ``LocalProvider``, reads `defaultListID` directly so the star icon
  /// updates immediately on mutation without an explicit reload.
  private func isDefault(_ listID: String, for provider: any TaskProvider) -> Bool {
    if let local = localProvider, provider.id == local.id {
      return local.defaultListID == listID
    }
    return (provider as? (any WritableTaskProvider))?.defaultListID == listID
  }

  // MARK: - Async list loading

  private func loadAllLists() async {
    for provider in enabledProviders where provider as? LocalProvider == nil {
      await loadLists(for: provider)
    }
  }

  private func loadLists(for provider: any TaskProvider) async {
    guard provider as? LocalProvider == nil else { return }
    listsByProvider[provider.id] = (try? await provider.lists()) ?? []
  }
}

#Preview {
  ProviderSidebarView(registry: TaskRegistry())
    .frame(width: 200, height: 400)
}
