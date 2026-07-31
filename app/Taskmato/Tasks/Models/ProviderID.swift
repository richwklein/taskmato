//
//  ProviderID.swift
//  Taskmato
//

import Foundation

/// A type-safe identifier for a ``TaskProvider``, wrapping the underlying string.
///
/// Using a newtype instead of a raw `String` catches every site where a non-provider
/// string could leak into provider comparisons, and produces clearer call sites
/// (`ref.providerID == LocalProvider.providerID` rather than `ref.providerID == "local"`).
///
/// `Codable` encodes as a bare string via a single-value container, so JSON and SwiftData
/// records stay byte-for-byte compatible with the previous `String`-typed representation.
/// `ExpressibleByStringLiteral` lets providers declare `static let providerID: ProviderID = "local"`.
nonisolated struct ProviderID: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {

  /// The underlying provider identifier string (e.g. `"local"`, `"obsidian"`, `"reminders"`).
  let rawValue: String

  /// Wraps an existing raw identifier string.
  init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Wraps a raw identifier string.
  init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  /// Creates an identifier from a string literal, enabling `let id: ProviderID = "local"`.
  init(stringLiteral value: String) {
    self.rawValue = value
  }
}

extension ProviderID: Codable {

  /// Decodes from a bare string value, preserving compatibility with `String`-typed records.
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.rawValue = try container.decode(String.self)
  }

  /// Encodes as a bare string value, preserving compatibility with `String`-typed records.
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
