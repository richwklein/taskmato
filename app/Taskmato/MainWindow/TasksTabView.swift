//
//  TasksTabView.swift
//  Taskmato
//

import SwiftUI

/// The task picker tab, showing tasks grouped by provider, list, and section with live search.
///
/// In single-provider mode the list groups are shown flat (one `DisclosureGroup` per list).
/// When two or more providers are enabled, an outer provider-level `DisclosureGroup` wraps
/// each provider's list groups. The Local provider's header includes an inline "+" button
/// in multi-provider mode; in single-provider mode the button lives in the toolbar.
struct TasksTabView: View {

  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry
  @Binding var selectedTab: Int

  @State private var query: String = ""
  @State private var providerGroups: [ProviderGroup] = []
  @State private var isLoading: Bool = false
  @State private var expandedGroups: [String: Bool] = [:]
  @State private var expandedProviders: [String: Bool] = [:]
  @State private var isAddingTask = false

  /// The local provider instance looked up from the registry, if registered.
  private var localProvider: LocalProvider? {
    registry.providers.first(where: { $0 is LocalProvider }) as? LocalProvider
  }

  /// `true` when the local provider is registered and currently enabled.
  private var localProviderEnabled: Bool {
    localProvider.map { registry.isEnabled($0.id) } ?? false
  }

  private var enabledProviderCount: Int {
    registry.providers.filter { registry.isEnabled($0.id) }.count
  }

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
      } else if providerGroups.isEmpty {
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
    .onChange(of: isAddingTask) { _, adding in
      if !adding { Task { await loadTasks() } }
    }
    .sheet(isPresented: $isAddingTask) {
      if let provider = localProvider {
        AddTaskView(provider: provider, isPresented: $isAddingTask)
      }
    }
    .toolbar {
      if localProviderEnabled && enabledProviderCount <= 1 {
        ToolbarItem(placement: .automatic) {
          Button {
            isAddingTask = true
          } label: {
            Label("Add Task", systemImage: "plus")
          }
          .help("Add a local task")
        }
      }
    }
  }

  // MARK: - Task list

  private var taskList: some View {
    List {
      if enabledProviderCount > 1 {
        ForEach(providerGroups) { provider in
          DisclosureGroup(isExpanded: providerExpansion(for: provider.id)) {
            ForEach(provider.lists) { group in
              listDisclosureGroup(for: group)
            }
          } label: {
            providerLabel(for: provider)
          }
        }
      } else {
        ForEach(providerGroups.first?.lists ?? []) { group in
          listDisclosureGroup(for: group)
        }
      }
    }
  }

  @ViewBuilder
  private func listDisclosureGroup(for group: TaskGroup) -> some View {
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

  @ViewBuilder
  private func providerLabel(for provider: ProviderGroup) -> some View {
    if localProviderEnabled, provider.id == localProvider?.id {
      HStack {
        Label(provider.displayName, systemImage: providerIcon(for: provider.id))
          .font(.subheadline)
          .fontWeight(.semibold)
        Spacer()
        Button {
          isAddingTask = true
        } label: {
          Image(systemName: "plus.circle")
        }
        .buttonStyle(.plain)
        .help("Add a local task")
      }
    } else {
      Label(provider.displayName, systemImage: providerIcon(for: provider.id))
        .font(.subheadline)
        .fontWeight(.semibold)
    }
  }

  private func providerIcon(for providerID: String) -> String {
    switch providerID {
    case "local": return "folder"
    case "obsidian": return "note.text"
    default: return "server.rack"
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

  /// Returns a stable ``Binding`` for the expanded state of the given list group.
  private func groupExpansion(for id: String) -> Binding<Bool> {
    Binding(
      get: { expandedGroups[id] ?? true },
      set: { expandedGroups[id] = $0 }
    )
  }

  /// Returns a stable ``Binding`` for the expanded state of the given provider group.
  private func providerExpansion(for id: String) -> Binding<Bool> {
    Binding(
      get: { expandedProviders[id] ?? true },
      set: { expandedProviders[id] = $0 }
    )
  }

  // MARK: - Data loading

  private func loadTasks() async {
    isLoading = providerGroups.isEmpty
    let (tasks, _) = await registry.tasks(matching: query)
    providerGroups = buildGroups(from: tasks)
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

  private func buildGroups(from tasks: [TaskItem]) -> [ProviderGroup] {
    var providerOrder: [String] = []
    var byProvider: [String: [TaskItem]] = [:]

    for task in tasks {
      let pid = task.id.providerID
      if byProvider[pid] == nil { providerOrder.append(pid) }
      byProvider[pid, default: []].append(task)
    }

    return providerOrder.compactMap { pid -> ProviderGroup? in
      guard let ptasks = byProvider[pid] else { return nil }
      let name = registry.providers.first(where: { $0.id == pid })?.displayName ?? pid
      return ProviderGroup(id: pid, displayName: name, lists: buildListGroups(from: ptasks))
    }
  }

  private func buildListGroups(from tasks: [TaskItem]) -> [TaskGroup] {
    var ordered: [String] = []
    var byKey: [String: [TaskItem]] = [:]

    for task in tasks {
      let key = task.list?.id ?? ""
      if byKey[key] == nil { ordered.append(key) }
      byKey[key, default: []].append(task)
    }

    return ordered.compactMap { key -> TaskGroup? in
      guard let items = byKey[key], let list = items.first?.list else { return nil }
      return TaskGroup(id: key, listName: list.name, sections: buildSections(from: items))
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

/// A grouped collection of task lists from a single provider.
private struct ProviderGroup: Identifiable {
  let id: String
  let displayName: String
  let lists: [TaskGroup]
}

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
