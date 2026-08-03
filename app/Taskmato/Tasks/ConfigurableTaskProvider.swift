//
//  ConfigurableTaskProvider.swift
//  Taskmato
//

import SwiftUI

/// A `TaskProvider` that exposes a user-facing setup sheet.
///
/// Conform to this protocol to opt in to the "Configure…" context-menu action in
/// the provider sidebar. The provider produces its own configuration view, so no
/// existing view needs to change when a new configurable provider is added.
protocol ConfigurableTaskProvider: TaskProvider {

  /// Whether the provider still needs user setup before it can serve tasks.
  ///
  /// Distinct from `isAuthorized`: a provider can be authorized (or not require
  /// authorization at all) while still missing required configuration, such as
  /// Obsidian's unselected vault. Enabling a provider for which this is `true`
  /// immediately presents ``configurationView()``.
  var needsConfiguration: Bool { get }

  /// Produces the view displayed inside the modal configuration sheet.
  @MainActor
  func configurationView() -> AnyView
}
