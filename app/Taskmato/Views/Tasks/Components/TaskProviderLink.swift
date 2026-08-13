//
//  TaskProviderLink.swift
//  Taskmato
//

import Foundation

/// A task's provider deep link plus the display values an "Open in …" affordance needs.
///
/// Resolves the "is there something to open, and what do we call it" rule as a plain,
/// unit-testable value — mirroring ``TaskItemPresenter``'s pattern of keeping display logic out
/// of the view layer. Only tasks with a `sourceURL` and a resolvable provider produce a link;
/// Local and ad-hoc tasks leave `sourceURL` `nil` and resolve to `nil` here too.
struct TaskProviderLink: Equatable, Sendable {

  /// The provider deep link to open.
  let url: URL
  /// The provider's display name, e.g. "Obsidian".
  let providerName: String
  /// The provider's SF Symbol icon.
  let icon: String

  /// Fails when `task` carries no `sourceURL` or its provider's name or icon is unknown.
  /// - Parameters:
  ///   - task: The task to resolve a link for.
  ///   - providerName: The owning provider's display name, or `nil` if unresolved.
  ///   - icon: The owning provider's SF Symbol icon, or `nil` if unresolved.
  init?(task: TaskItem, providerName: String?, icon: String?) {
    guard let url = task.sourceURL, let providerName, let icon else { return nil }
    self.url = url
    self.providerName = providerName
    self.icon = icon
  }

  /// Title-style command label, e.g. "Open in Obsidian".
  var title: String { "Open in \(providerName)" }

  /// The paired title and icon for menu items offering this link.
  var label: AppLabel { AppLabel(title, systemImage: icon) }
}

@MainActor
extension TaskProviderLink {

  /// Resolves the link for `task` against `registry`, or `nil` when there is nothing to open.
  /// - Parameters:
  ///   - task: The task to resolve a link for.
  ///   - registry: The registry used to look up the owning provider's name and icon.
  init?(task: TaskItem, registry: ProviderRegistry) {
    let provider = registry.provider(for: task.id)
    self.init(task: task, providerName: provider?.displayName, icon: provider?.icon)
  }
}
