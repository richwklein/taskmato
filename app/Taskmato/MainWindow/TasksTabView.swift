//
//  TasksTabView.swift
//  Taskmato
//

import SwiftUI

/// The task picker tab, showing tasks grouped by list and section with live search.
///
/// Selecting a task sets it as the active task and switches to the Timer tab.
/// Each list group is collapsible via a `DisclosureGroup` with a document icon.
struct TasksTabView: View {

  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  @Binding var selectedTab: Int

  @State private var query: String = ""
  @State private var groupedLists: [TaskGroup] = []
  @State private var isLoading: Bool = false
  @State private var expandedGroups: [String: Bool] = [:]

  var body: some View {
    Group {
      if registry.providers.filter({ registry.isEnabled($0.id) }).isEmpty {
        ContentUnavailableView(
          "No Task Providers",
          systemImage: "tray",
          description: Text("Enable a task provider in Settings to see your tasks here.")
        )
      } else if isLoading {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if groupedLists.isEmpty {
        ContentUnavailableView(
          query.isEmpty ? "No Tasks" : "No Results",
          systemImage: query.isEmpty ? "checkmark.circle" : "magnifyingglass",
          description: Text(
            query.isEmpty
              ? "All tasks from your providers will appear here."
              : "No tasks match \"\(query)\"."
          )
        )
      } else {
        taskList
      }
    }
    .searchable(text: $query, prompt: "Search tasks")
    .task(id: query) { await loadTasks() }
    .onAppear { Task { await loadTasks() } }
  }

  // MARK: - Task list

  private var taskList: some View {
    List {
      ForEach(groupedLists) { group in
        DisclosureGroup(
          isExpanded: groupExpansion(for: group.id)
        ) {
          ForEach(group.sections) { section in
            if let sectionName = section.name {
              sectionSeparator(sectionName)
            }
            ForEach(section.tasks) { task in
              TaskRowView(
                task: task,
                onComplete: registry.mutableProvider(for: task.id) != nil
                  ? { handleComplete(task) }
                  : nil
              )
              .onTapGesture { select(task) }
            }
          }
        } label: {
          Label(group.listName, systemImage: "doc.text")
            .font(.subheadline)
            .fontWeight(.semibold)
        }
      }
    }
  }

  /// A non-interactive visual separator row showing the section heading.
  @ViewBuilder
  private func sectionSeparator(_ name: String) -> some View {
    Text(name)
      .font(.caption2)
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
      .listRowBackground(Color.clear)
      .padding(.top, 4)
  }

  /// Returns a stable ``Binding`` for the expanded state of the given group.
  private func groupExpansion(for id: String) -> Binding<Bool> {
    Binding(
      get: { expandedGroups[id] ?? true },
      set: { expandedGroups[id] = $0 }
    )
  }

  // MARK: - Data loading

  private func loadTasks() async {
    isLoading = groupedLists.isEmpty
    let (tasks, _) = await registry.tasks(matching: query)
    groupedLists = buildGroups(from: tasks)
    isLoading = false
  }

  private func select(_ task: TaskItem) {
    selectionStore.select(task)
    selectedTab = 0
  }

  /// Completes the task via its mutable provider, then refreshes the list.
  private func handleComplete(_ task: TaskItem) {
    let ref = task.id
    Task {
      if let provider = registry.mutableProvider(for: ref) {
        try? await provider.complete(ref)
      }
      await loadTasks()
    }
  }

  // MARK: - Grouping

  private func buildGroups(from tasks: [TaskItem]) -> [TaskGroup] {
    var ordered: [String] = []
    var byKey: [String: [TaskItem]] = [:]

    for task in tasks {
      let key = task.list?.id ?? ""
      if byKey[key] == nil { ordered.append(key) }
      byKey[key, default: []].append(task)
    }

    return ordered.compactMap { key -> TaskGroup? in
      guard let tasks = byKey[key], let list = tasks.first?.list else { return nil }
      let sections = buildSections(from: tasks)
      return TaskGroup(id: key, listName: list.name, sections: sections)
    }
  }

  private func buildSections(from tasks: [TaskItem]) -> [TaskSection] {
    var ordered: [String?] = []
    var bySection: [String?: [TaskItem]] = [:]

    for task in tasks {
      let key = task.section
      if bySection[key] == nil { ordered.append(key) }
      bySection[key, default: []].append(task)
    }

    return ordered.map { key in
      TaskSection(
        id: key ?? "_unsectioned_",
        name: key,
        tasks: bySection[key] ?? []
      )
    }
  }
}

// MARK: - Supporting types

/// A grouped collection of tasks sharing a ``TaskList``.
private struct TaskGroup: Identifiable {
  let id: String
  let listName: String
  let sections: [TaskSection]
}

/// A collection of tasks under a single section heading within a list.
private struct TaskSection: Identifiable {
  let id: String
  let name: String?
  let tasks: [TaskItem]
}

#Preview {
  TasksTabView(
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry(),
    selectedTab: .constant(1)
  )
}
