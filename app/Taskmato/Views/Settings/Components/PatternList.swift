//
//  PatternList.swift
//  Taskmato
//

import Foundation

/// Parses user-typed, comma-separated pattern lists into trimmed, non-empty entries.
///
/// Shared by the Obsidian file-pattern field and the Reminders list-pattern field.
enum PatternList {

  /// Splits `text` on commas, trims surrounding whitespace, and drops empty entries.
  static func parse(_ text: String) -> [String] {
    text
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}
