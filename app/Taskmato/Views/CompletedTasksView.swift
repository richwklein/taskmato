//
//  CompletedTasksView.swift
//  Taskmato
//

import SwiftUI

/// A sheet listing tasks marked complete by all enabled ``MutableTaskProvider``s.
///
/// Each row offers a "Reopen" swipe action to un-complete the task. The Local provider
/// additionally shows a destructive "Delete" action to permanently remove the task.
/// Changes are reflected in the local list immediately; the caller is responsible for
/// refreshing the main task picker after the sheet is dismissed.
struct CompletedTasksView: View {

  var registry: TaskRegistry
  @Binding var isPresented: Bool

  @State private var grouped: [(provider: any MutableTaskProvider, tasks: [TaskItem])] = []
  @State private var isLoading = true

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if grouped.allSatisfy({ $0.tasks.isEmpty }) {
          ContentUnavailableView(
            "No Completed Tasks",
            systemImage: "checkmark.circle",
            description: Text("Tasks you complete will appear here.")
          )
        } else {
          completedList
        }
      }
      .navigationTitle("Completed")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { isPresented = false }
        }
      }
    }
    .frame(minWidth: 340, minHeight: 260)
    .task { await load() }
  }

  // MARK: - List

  private var completedList: some View {
    List {
      ForEach(grouped.indices, id: \.self) { idx in
        let entry = grouped[idx]
        if registry.providers.filter({ registry.isEnabled($0.id) }).count > 1 {
          Section(entry.provider.displayName) {
            completedRows(providerIndex: idx, tasks: entry.tasks, provider: entry.provider)
          }
        } else {
          completedRows(providerIndex: idx, tasks: entry.tasks, provider: entry.provider)
        }
      }
    }
  }

  @ViewBuilder
  private func completedRows(
    providerIndex: Int,
    tasks: [TaskItem],
    provider: any MutableTaskProvider
  ) -> some View {
    ForEach(tasks) { task in
      HStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.secondary)
        Text(task.title)
          .font(.callout)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, 2)
      .swipeActions(edge: .trailing) {
        Button("Reopen") { reopen(task, at: providerIndex) }
          .tint(.accentColor)
        if provider is LocalProvider {
          Button("Delete", role: .destructive) { delete(task, at: providerIndex) }
        }
      }
    }
  }

  // MARK: - Actions

  private func reopen(_ task: TaskItem, at index: Int) {
    let ref = task.id
    Task {
      try? await grouped[index].provider.reopen(ref)
      grouped[index].tasks.removeAll { $0.id == ref }
    }
  }

  private func delete(_ task: TaskItem, at index: Int) {
    let ref = task.id
    guard let local = grouped[index].provider as? LocalProvider else { return }
    try? local.deleteTask(ref)
    grouped[index].tasks.removeAll { $0.id == ref }
  }

  // MARK: - Data loading

  private func load() async {
    let providers: [any MutableTaskProvider] = registry.providers
      .filter { registry.isEnabled($0.id) }
      .compactMap { $0 as? any MutableTaskProvider }

    var result: [(provider: any MutableTaskProvider, tasks: [TaskItem])] = []
    await withTaskGroup(of: (any MutableTaskProvider, [TaskItem]).self) { group in
      for provider in providers {
        group.addTask {
          let tasks = (try? await provider.completedTasks()) ?? []
          return (provider, tasks)
        }
      }
      for await (provider, tasks) in group {
        result.append((provider: provider, tasks: tasks))
      }
    }

    // Sort to match registry order
    let order = providers.map { $0.id }
    grouped = result.sorted { lhs, rhs in
      (order.firstIndex(of: lhs.provider.id) ?? 0) < (order.firstIndex(of: rhs.provider.id) ?? 0)
    }
    isLoading = false
  }
}
