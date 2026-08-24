//
//  ListConfigurationToken.swift
//  Taskmato
//

import Foundation

/// The configuration inputs that determine which lists ``TaskProvider/lists()`` returns,
/// compared by value so views that cache list results reload when they change.
struct ListConfigurationToken: Equatable, Sendable {

  /// The switchable source whose change alters list membership, or `nil` when the provider
  /// has no such source or its source is not yet configured.
  var source: String?

  /// The membership-restricting patterns, held as a set because matching is order- and
  /// duplicate-independent, so equivalent pattern edits compare equal.
  var patterns: Set<String> = []
}
