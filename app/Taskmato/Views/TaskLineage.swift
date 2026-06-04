//
//  TaskLineage.swift
//  Taskmato
//

/// Describes a task's provenance through the Provider → List → Section hierarchy.
///
/// Passed to task views when the picker is in cross-provider flat mode (Today or search).
/// The provider icon is only included when multiple providers are enabled — with a single
/// provider the icon is redundant and is omitted.
struct TaskLineage {
  /// SF Symbol name for the provider icon, or `nil` when only one provider is enabled.
  let providerIcon: String?
  /// The list the task belongs to, if any.
  let listName: String?
  /// The provider-level section the task belongs to, if any.
  let sectionName: String?

  /// The most specific non-redundant context label to display.
  ///
  /// Returns `sectionName` when it is present and differs from `listName`; otherwise
  /// returns `listName`; otherwise `nil`. Prevents `"Work > Work"` when a provider
  /// creates a section with the same name as the list.
  var contextLabel: String? {
    if let section = sectionName, section != listName { return section }
    return listName
  }

  /// `true` when there is nothing to display — no icon and no context label.
  var isEmpty: Bool { providerIcon == nil && contextLabel == nil }
}
