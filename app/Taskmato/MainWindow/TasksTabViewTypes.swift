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
