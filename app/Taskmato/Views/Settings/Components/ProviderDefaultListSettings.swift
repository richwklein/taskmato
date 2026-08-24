//
//  ProviderDefaultListSettings.swift
//  Taskmato
//

import SwiftUI

/// A provider-scoped control for choosing the list used by new tasks.
struct ProviderDefaultListSettings: View {

  let provider: any WritableTaskProvider

  @State private var lists: [TaskList] = []
  @State private var selectedListID = ""
  /// The selection ``loadLists()`` last applied itself; a change to this value is programmatic,
  /// not a user pick, and must not overwrite the stored default.
  @State private var appliedSelection = ""
  @State private var isLoading = true
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: .contentGap) {
      Text("Task creation")
        .font(.headline)

      Text(
        "This list is used when a new task does not specify a list. "
          + "Lists chosen in the sidebar or supplied by a URL or command take precedence."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack(alignment: .firstTextBaseline, spacing: .contentGap) {
        Text("Default list")
          .frame(width: 92, alignment: .trailing)

        if lists.isEmpty, !isLoading {
          Text("No lists available")
            .foregroundStyle(.secondary)
        } else {
          Picker("Default list", selection: $selectedListID) {
            ForEach(lists) { list in
              Text(list.name).tag(list.id)
            }
          }
          .labelsHidden()
          .disabled(isLoading)
        }
      }

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(Color.statusError)
          .padding(.leading, 92 + .contentGap)
      }
    }
    // Reloads on configuration changes (patterns/vault) only — deliberately not subscribed to
    // observe(); external data changes refresh on next open and fail safe via setDefaultList.
    .task(id: provider.listConfiguration) { await loadLists() }
    .onChange(of: selectedListID) { _, newValue in
      // Persist only a user-driven pick. A value loadLists() applied itself equals
      // appliedSelection and must not overwrite the stored default — the isLoading flag can't
      // gate this, because onChange fires on a later update pass after loadLists() has already
      // reset it.
      guard !newValue.isEmpty, newValue != appliedSelection else { return }
      appliedSelection = newValue
      Task { await saveDefaultList(newValue) }
    }
  }

  private func loadLists() async {
    let token = provider.listConfiguration
    do {
      let loaded = try await provider.lists()
      guard token == provider.listConfiguration else { return }
      lists = loaded
      errorMessage = nil
      let resolved =
        DefaultListResolver.resolve(among: loaded, storedDefault: provider.defaultListID) ?? ""
      appliedSelection = resolved
      selectedListID = resolved
      isLoading = false
    } catch {
      guard token == provider.listConfiguration else { return }
      errorMessage = error.localizedDescription
      isLoading = false
    }
  }

  private func saveDefaultList(_ listID: String) async {
    do {
      try await provider.setDefaultList(listID)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
