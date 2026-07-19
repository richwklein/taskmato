//
//  TasksTabSections.swift
//  Taskmato
//

/// The structural display style of a rendered task section.
enum TaskDisplayStyle {
  /// Tasks are grouped within a named list. The section header is visible.
  case sectioned
  /// Tasks are drawn from multiple providers as a flat list.
  ///
  /// The section header is hidden; each task row shows its lineage instead.
  case flat
}

/// A display-ready section of tasks for the task picker list or grid.
struct TaskSection: Identifiable {
  /// Composite identifier: `"<listID>.<sectionKey>"`, or `"_flat_"` in flat mode.
  let id: String
  /// The list identifier this section belongs to — used to bucket completed tasks.
  let listID: String
  /// Computed header label. Empty string when `displayStyle == .flat`.
  let header: String
  /// The tasks to display in this section.
  let tasks: [TaskItem]
  /// Controls header visibility and lineage display in task rows.
  var displayStyle: TaskDisplayStyle = .sectioned
}

/// Computes the display header for a section given its list and provider-section context.
///
/// - Parameters:
///   - listName: The name of the list this section belongs to.
///   - sectionName: The provider-level section name, if any.
///   - isMultiList: Whether the picker is showing tasks from more than one list.
/// - Returns: The header string to display above the section.
func sectionHeader(listName: String, sectionName: String?, isMultiList: Bool) -> String {
  switch (isMultiList, sectionName) {
  case (true, let name?): return "\(listName): \(name)"
  case (true, nil): return listName
  case (false, let name?): return name
  case (false, nil): return listName
  }
}

/// Converts a flat array of tasks into display-ready sections based on the active query.
///
/// - Parameters:
///   - tasks: The flat task array from the registry.
///   - query: The active query; determines flat vs. sectioned display.
/// - Returns: Display-ready `TaskSection` array, empty when `tasks` is empty.
func buildDisplaySections(from tasks: [TaskItem], query: TaskQuery) -> [TaskSection] {
  guard !query.isCrossProvider else {
    guard !tasks.isEmpty else { return [] }
    return [
      TaskSection(
        id: "_flat_", listID: "_flat_", header: "", tasks: tasks, displayStyle: .flat)
    ]
  }
  var listOrder: [String] = []
  var byList: [String: (name: String, tasks: [TaskItem])] = [:]
  for task in tasks {
    let key = task.list?.id ?? ""
    if byList[key] == nil {
      listOrder.append(key)
      byList[key] = (name: task.list?.name ?? "", tasks: [])
    }
    byList[key]?.tasks.append(task)
  }
  let isMultiList = listOrder.count > 1
  return listOrder.flatMap { listID -> [TaskSection] in
    guard let (listName, listTasks) = byList[listID] else { return [] }
    var secOrder: [String?] = []
    var bySec: [String?: [TaskItem]] = [:]
    for task in listTasks {
      if bySec[task.section] == nil { secOrder.append(task.section) }
      bySec[task.section, default: []].append(task)
    }
    return secOrder.map { secKey in
      TaskSection(
        id: "\(listID).\(secKey ?? "_unsectioned_")",
        listID: listID,
        header: sectionHeader(
          listName: listName, sectionName: secKey, isMultiList: isMultiList),
        tasks: bySec[secKey] ?? []
      )
    }
  }
}
