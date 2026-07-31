//
//  ContentFormat.swift
//  Taskmato
//

import Foundation

/// Declares how a task's `title` and `notes` strings should be interpreted for display.
nonisolated enum ContentFormat: Codable, Sendable {

  /// Plain text — rendered verbatim, no markdown interpretation.
  case plainText

  /// Markdown — rendered via `AttributedString(markdown:)` where supported.
  case markdown
}
