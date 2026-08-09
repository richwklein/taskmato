//
//  ObsidianTaskLineFormatter.swift
//  Taskmato
//

import Foundation

/// Serializes task fields into an obsidian-tasks-plugin formatted markdown line.
///
/// The inverse of ``ObsidianTaskParser``'s field extraction — produces lines the parser can
/// read back unchanged. All formatting is pure (no file I/O), making this testable without a
/// filesystem.
nonisolated struct ObsidianTaskLineFormatter: Sendable {

  /// Builds a single `- [ ] Title 🔺 🛫 yyyy-MM-dd ⏰ yyyy-MM-dd 📅 yyyy-MM-dd` task line.
  ///
  /// - Parameters:
  ///   - title: The task title, written verbatim (trimmed).
  ///   - checkbox: The checkbox character (`" "` for incomplete, `"x"` for complete).
  ///   - priority: Appended as the matching priority emoji, omitted for `.none`.
  ///   - startDate: Appended as `🛫 yyyy-MM-dd`, when present.
  ///   - scheduledDate: Appended as `⏰ yyyy-MM-dd`, when present.
  ///   - dueDate: Appended as `📅 yyyy-MM-dd`, when present.
  /// - Returns: The formatted task line, with no trailing newline.
  func formatLine(
    title: String,
    checkbox: String = " ",
    priority: TaskPriority = .none,
    startDate: Date? = nil,
    scheduledDate: Date? = nil,
    dueDate: Date? = nil
  ) -> String {
    var line = "- [\(checkbox)] \(title.trimmingCharacters(in: .whitespaces))"

    if let emoji = Self.priorityEmoji(for: priority) {
      line += " \(emoji)"
    }
    if let startDate {
      line += " 🛫 \(Self.dateString(startDate))"
    }
    if let scheduledDate {
      line += " ⏰ \(Self.dateString(scheduledDate))"
    }
    if let dueDate {
      line += " 📅 \(Self.dateString(dueDate))"
    }
    return line
  }

  /// Formats `notes` as 4-space-indented continuation lines following a task line, matching how
  /// ``ObsidianTaskParser`` reads indented lines back as a task's `notes`.
  ///
  /// Returns an empty array when `notes` is blank.
  func formatNoteLines(_ notes: String) -> [String] {
    let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    return trimmed.components(separatedBy: "\n").map { "    " + $0 }
  }

  /// Returns the priority emoji for `priority`, or `nil` for `.none`.
  private static func priorityEmoji(for priority: TaskPriority) -> String? {
    ObsidianTaskParser.priorityEmojis.first { $0.1 == priority }?.0
  }

  /// Formats `date` as `yyyy-MM-dd`, matching ``ObsidianTaskParser``'s date-extraction format.
  private static func dateString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.string(from: date)
  }
}
