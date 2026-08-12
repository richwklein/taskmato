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
///
/// `String`-backed and `Codable` so the ``FocusSegment`` provider-cosmetics snapshot
/// (ADR-0010, D4) has a stable on-disk representation independent of case ordering.
nonisolated enum ProviderTint: String, Codable, Equatable, Sendable {

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

extension ProviderTint {

  /// Decodes leniently, mapping an unrecognized raw value to ``gray``.
  ///
  /// A record written by a newer build may carry a tint case this build has never seen.
  /// Segments decode as an array, so throwing here would discard a whole record's focus
  /// attribution rather than a single swatch.
  nonisolated init(from decoder: any Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = ProviderTint(rawValue: raw) ?? .gray
  }
}
