//
//  ProviderTint.swift
//  Taskmato
//

import Foundation

/// A provider's semantic display color, resolved to a concrete `Color` in the view layer.
///
/// A plain, Foundation-only token — the sibling of ``TaskProvider/icon`` — so the `Tasks`
/// layer carries provider visual identity without importing SwiftUI. The Stats views map
/// each case to a `Color`; focus time with no provider falls back to ``gray``.
enum ProviderTint: Equatable, Sendable {

  /// Blue accent.
  case blue

  /// Green accent.
  case green

  /// Orange accent.
  case orange

  /// Purple accent.
  case purple

  /// Neutral gray, used for untracked focus time and providers with no explicit tint.
  case gray
}
