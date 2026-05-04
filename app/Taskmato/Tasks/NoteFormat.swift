//
//  NoteFormat.swift
//  Taskmato
//

import Foundation

/// Declares how a task's `notes` string should be interpreted for display.
enum NoteFormat: Codable, Sendable {

  /// Plain text — rendered verbatim, no markdown interpretation.
  case plainText

  /// Markdown — rendered via `AttributedString(markdown:)` where supported.
  case markdown
}
