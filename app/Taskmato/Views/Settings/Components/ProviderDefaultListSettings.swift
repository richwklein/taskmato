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
    .task { await loadLists() }
    .onChange(of: selectedListID) { _, newValue in
      guard !isLoading, !newValue.isEmpty else { return }
      Task { await saveDefaultList(newValue) }
    }
  }

  private func loadLists() async {
    defer { isLoading = false }
    do {
      lists = try await provider.lists()
      if let defaultListID = provider.defaultListID {
        if lists.contains(where: { $0.id == defaultListID }) {
          selectedListID = defaultListID
        } else {
          selectedListID = lists.first?.id ?? ""
        }
      } else {
        selectedListID = lists.first?.id ?? ""
      }
    } catch {
      errorMessage = error.localizedDescription
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
