//
//  LocalSettingsView.swift
//  Taskmato
//

import SwiftUI

/// List-management rows for the local task provider.
///
/// Rendered inside a "Local Tasks" `Section` in ``SettingsView`` when the local
/// provider is enabled. Supports creating, renaming (via inline text fields), and
/// deleting lists. Does not include a `Section` wrapper — the caller is responsible.
@MainActor
struct LocalSettingsView: View {

  var provider: LocalProvider
  var scopeStore: TaskListScopeStore?

  @State private var newListName = ""
  @State private var pendingNames: [UUID: String] = [:]

  var body: some View {
    Group {
      LabeledContent("Active tasks", value: "\(provider.activeTaskCount)")

      ForEach(provider.taskLists) { list in
        listRow(list)
      }

      HStack {
        TextField("New list name", text: $newListName)
          .onSubmit { addList() }
        Button("Add") { addList() }
          .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
      }

      if let scopeStore, provider.taskLists.count > 1 {
        Divider()
        Text("Visible Lists")
          .font(.subheadline)
          .fontWeight(.semibold)
        ForEach(provider.taskLists) { list in
          Toggle(
            list.name,
            isOn: Binding(
              get: { scopeStore.isListEnabled(list.id.uuidString, for: LocalProvider.providerID) },
              set: { _ in scopeStore.toggleList(list.id.uuidString, for: LocalProvider.providerID) }
            )
          )
        }
      }
    }
  }

  // MARK: - List row

  private func listRow(_ list: LocalList) -> some View {
    HStack {
      TextField(
        "List name",
        text: Binding(
          get: { pendingNames[list.id] ?? list.name },
          set: { pendingNames[list.id] = $0 }
        )
      )
      .textFieldStyle(.plain)
      .onSubmit { commitRename(list) }

      Button(role: .destructive) {
        provider.deleteList(list.id)
        pendingNames.removeValue(forKey: list.id)
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.red)
      .disabled(provider.taskLists.count == 1)
    }
    .onChange(of: list.name) { _, newName in
      // Keep the editing buffer in sync if provider updates the name externally.
      if pendingNames[list.id] == list.name { pendingNames.removeValue(forKey: list.id) }
      _ = newName
    }
  }

  // MARK: - Actions

  private func commitRename(_ list: LocalList) {
    guard let pending = pendingNames[list.id] else { return }
    let trimmed = pending.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty && trimmed != list.name {
      try? provider.renameList(list.id, name: trimmed)
    }
    pendingNames.removeValue(forKey: list.id)
  }

  private func addList() {
    let trimmed = newListName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    provider.createList(name: trimmed)
    newListName = ""
  }
}
