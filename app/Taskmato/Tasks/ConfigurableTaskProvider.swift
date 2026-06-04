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

  /// Produces the view displayed inside the modal configuration sheet.
  @MainActor
  func configurationView() -> AnyView
}
