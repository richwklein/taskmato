//
//  TaskSorter.swift
//  Taskmato
//

import Foundation

/// Pure value that orders ``TaskItem`` collections by a field and direction.
///
/// Sorting is stateless, so `TaskSorter` carries no configuration and is safe to share
/// across concurrency domains. It is the sort concern extracted from the former
/// `ProviderRegistry` façade; the query layer owns an instance and delegates ordering to it.
struct TaskSorter: Sendable {

  /// Sorts `items` by `field`/`direction`.
  ///
  /// When `preserveSections` is `true`, the sort is applied within each `(list.id, section)`
  /// group in encounter order and the groups are flattened back to a single array — preserving
  /// the section order the providers produced. When `false`, the array is sorted globally and
  /// section boundaries are ignored.
  ///
  /// - Parameters:
  ///   - items: The tasks to order.
  ///   - field: The field to sort by.
  ///   - direction: The sort direction.
  ///   - preserveSections: Whether to keep provider section order (defaults to `true`).
  /// - Returns: The ordered tasks.
  func sorted(
    _ items: [TaskItem],
    by field: TaskSortField,
    direction: TaskSortDirection,
    preserveSections: Bool = true
  ) -> [TaskItem] {
    guard preserveSections else {
      return items.sorted { compareItems($0, $1, field: field, direction: direction) }
    }

    struct SectionKey: Hashable {
      let listID: String
      let section: String?
    }

    var ordered: [SectionKey] = []
    var bySection: [SectionKey: [TaskItem]] = [:]

    for item in items {
      let key = SectionKey(listID: item.list?.id ?? "", section: item.section)
      if bySection[key] == nil { ordered.append(key) }
      bySection[key, default: []].append(item)
    }

    return ordered.flatMap { key in
      (bySection[key] ?? []).sorted { compareItems($0, $1, field: field, direction: direction) }
    }
  }

  private func compareItems(
    _ lhs: TaskItem, _ rhs: TaskItem, field: TaskSortField, direction: TaskSortDirection
  ) -> Bool {
    let asc = direction == .ascending
    switch field {
    case .dueDate:
      return compareDatesNilLast(lhs.dueDate, rhs.dueDate, ascending: asc)
        ?? compareTitlesAscending(lhs.title, rhs.title)
        ?? compareRefs(lhs.id, rhs.id)
    case .priority:
      if lhs.priority != rhs.priority {
        return asc ? lhs.priority < rhs.priority : lhs.priority > rhs.priority
      }
      return compareDatesNilLast(lhs.dueDate, rhs.dueDate, ascending: true)
        ?? compareTitlesAscending(lhs.title, rhs.title)
        ?? compareRefs(lhs.id, rhs.id)
    case .title:
      let cmp = lhs.title.localizedStandardCompare(rhs.title)
      if cmp != .orderedSame { return asc ? cmp == .orderedAscending : cmp == .orderedDescending }
      return compareRefs(lhs.id, rhs.id)
    case .creationDate:
      return compareDatesNilLast(lhs.createdAt, rhs.createdAt, ascending: asc)
        ?? compareTitlesAscending(lhs.title, rhs.title)
        ?? compareRefs(lhs.id, rhs.id)
    }
  }

  /// Compares two optional dates with nil-last semantics. Returns `nil` when both are equal or both nil.
  private func compareDatesNilLast(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool? {
    switch (lhs, rhs) {
    case (let lhsDate?, let rhsDate?):
      guard lhsDate != rhsDate else { return nil }
      return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
    case (.some, .none): return true
    case (.none, .some): return false
    case (.none, .none): return nil
    }
  }

  /// Ascending title comparison using `localizedStandardCompare`. Returns `nil` when equal.
  private func compareTitlesAscending(_ lhs: String, _ rhs: String) -> Bool? {
    let result = lhs.localizedStandardCompare(rhs)
    return result == .orderedSame ? nil : result == .orderedAscending
  }

  /// Deterministic tiebreaker using the lexicographic order of `providerID/nativeID`.
  private func compareRefs(_ lhs: TaskRef, _ rhs: TaskRef) -> Bool {
    "\(lhs.providerID)/\(lhs.nativeID)" < "\(rhs.providerID)/\(rhs.nativeID)"
  }
}
