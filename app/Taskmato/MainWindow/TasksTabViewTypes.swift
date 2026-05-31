//
//  TasksTabViewTypes.swift
//  Taskmato
//

/// A grouped collection of tasks sharing a ``TaskList``.
struct TaskGroup: Identifiable {
  let id: String
  let listName: String
  let sections: [TaskSection]
}

/// A collection of tasks under a single section heading within a list.
struct TaskSection: Identifiable {
  let id: String
  let name: String?
  let tasks: [TaskItem]
}

/// A flattened display section with a computed header label and its tasks.
struct FlatSection: Identifiable {
  let id: String
  /// The ``TaskList`` identifier this section belongs to — used to bucket completed tasks.
  let listID: String
  let header: String
  let tasks: [TaskItem]
}

/// Flattens grouped lists into display sections with computed header labels.
///
/// Header rules:
/// - Single list + section name → section name
/// - Single list + no section name → list name
/// - Multiple lists + section name → "List: Section"
/// - Multiple lists + no section name → list name
func flatSections(from groupedLists: [TaskGroup]) -> [FlatSection] {
  let multipleGroups = groupedLists.count > 1
  return groupedLists.flatMap { group in
    group.sections.map { section in
      let header: String
      switch (multipleGroups, section.name) {
      case (true, let name?): header = "\(group.listName): \(name)"
      case (true, nil): header = group.listName
      case (false, let name?): header = name
      case (false, nil): header = group.listName
      }
      return FlatSection(
        id: "\(group.id).\(section.id)", listID: group.id, header: header, tasks: section.tasks
      )
    }
  }
}
