//
//  ObsidianTaskParser.swift
//  Taskmato
//

import Foundation

/// Parses the obsidian-tasks plugin format from raw markdown text into ``TaskItem`` values.
///
/// All file I/O is the caller's responsibility — this type accepts a plain `String` and
/// returns parsed tasks, making it straightforward to unit-test without a filesystem.
struct ObsidianTaskParser {

  // MARK: - Public interface

  /// The result of parsing a single markdown file for incomplete tasks.
  struct ParseResult {
    /// Incomplete tasks found in the file, in source order.
    let items: [TaskItem]
    /// Text of the first H1 heading in the file, if any — used to name the ``TaskList``.
    let listName: String?
  }

  /// The result of parsing a single markdown file for completed tasks.
  struct CompletedParseResult {
    /// Completed tasks paired with their `✅` completion dates (nil when the date is absent).
    let entries: [(item: TaskItem, completedAt: Date?)]
    /// Text of the first H1 heading in the file, if any — used to name the ``TaskList``.
    let listName: String?
  }

  /// Parses all incomplete tasks from `content`.
  ///
  /// - Parameters:
  ///   - content: The full text of a markdown file.
  ///   - providerID: The ``TaskProvider`` identifier used to build ``TaskRef`` values.
  ///   - fileRelativePath: Vault-relative path used to build stable ``TaskRef`` native IDs
  ///     and the Obsidian deep-link URL.
  ///   - vaultName: Obsidian vault name used in `obsidian://open` deep links.
  ///   - list: The ``TaskList`` this file maps to; passed through to each emitted ``TaskItem``.
  /// - Returns: Parsed tasks and the optional H1-derived list name.
  func parse(
    content: String,
    providerID: String,
    fileRelativePath: String,
    vaultName: String,
    list: TaskList
  ) -> ParseResult {
    let context = FileContext(
      providerID: providerID,
      fileRelativePath: fileRelativePath,
      vaultName: vaultName,
      list: list
    )
    let (raw, listName) = collectEntries(
      from: content,
      isTarget: isIncompleteTask,
      shouldSkip: isCompletedTask
    )
    let items = raw.map { entry in
      buildTaskItem(
        rawLine: entry.rawLine, lineNumber: entry.lineNumber,
        section: entry.section, notes: entry.notes, context: context
      )
    }
    return ParseResult(items: items, listName: listName)
  }

  /// Parses all completed (`- [x]` / `- [X]`) tasks from `content`.
  ///
  /// Each entry includes the parsed ``TaskItem`` and the `✅ YYYY-MM-DD` completion date
  /// (nil when the emoji is absent), allowing callers to sort by recency.
  func parseCompleted(
    content: String,
    providerID: String,
    fileRelativePath: String,
    vaultName: String,
    list: TaskList
  ) -> CompletedParseResult {
    let context = FileContext(
      providerID: providerID,
      fileRelativePath: fileRelativePath,
      vaultName: vaultName,
      list: list
    )
    let (raw, listName) = collectEntries(
      from: content,
      isTarget: isCompletedTask,
      shouldSkip: isIncompleteTask
    )
    let entries = raw.map { entry in
      buildCompletedEntry(
        rawLine: entry.rawLine, lineNumber: entry.lineNumber,
        section: entry.section, notes: entry.notes, context: context
      )
    }
    return CompletedParseResult(entries: entries, listName: listName)
  }

  // MARK: - State machine

  /// Raw task line collected by the state machine before field extraction.
  private struct RawEntry {
    let lineNumber: Int
    let rawLine: String
    let section: String?
    let notes: String?
  }

  /// Walks `content` line by line and collects task lines that pass `isTarget`, skipping those
  /// that match `shouldSkip`. H1 headings, subheadings, and indented continuation lines are
  /// handled identically regardless of which task type is being collected.
  private func collectEntries(
    from content: String,
    isTarget: (String) -> Bool,
    shouldSkip: (String) -> Bool
  ) -> (entries: [RawEntry], listName: String?) {
    let lines = content.components(separatedBy: "\n")
    var collected: [RawEntry] = []
    var listName: String?
    var currentSection: String?
    var pendingLine: Int?
    var pendingRaw: String?
    var pendingSection: String?
    var notesBuffer: [String] = []

    func finalize() {
      guard let lineNo = pendingLine, let raw = pendingRaw else { return }
      let notes = notesBuffer.joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      collected.append(
        RawEntry(
          lineNumber: lineNo,
          rawLine: raw,
          section: pendingSection,
          notes: notes.isEmpty ? nil : notes
        )
      )
      pendingLine = nil
      pendingRaw = nil
      pendingSection = nil
      notesBuffer = []
    }

    for (zeroIndex, line) in lines.enumerated() {
      let lineNumber = zeroIndex + 1
      if let heading = h1(line) {
        finalize()
        if listName == nil { listName = heading }
      } else if let heading = subheading(line) {
        finalize()
        currentSection = heading
      } else if isTarget(line) {
        finalize()
        pendingLine = lineNumber
        pendingRaw = line
        pendingSection = currentSection
      } else if shouldSkip(line) {
        finalize()
      } else if pendingLine != nil, isIndented(line) {
        notesBuffer.append(stripIndent(line))
      } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
        finalize()
      }
    }
    finalize()

    return (collected, listName)
  }

  // MARK: - Line classification

  private func h1(_ line: String) -> String? {
    guard line.hasPrefix("# ") else { return nil }
    return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
  }

  private func subheading(_ line: String) -> String? {
    guard
      line.hasPrefix("## ") || line.hasPrefix("### ") || line.hasPrefix("#### ")
        || line.hasPrefix("##### ") || line.hasPrefix("###### ")
    else { return nil }
    if let spaceIdx = line.firstIndex(of: " ") {
      return String(line[line.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
    }
    return nil
  }

  private func isIncompleteTask(_ line: String) -> Bool {
    line.hasPrefix("- [ ] ") || matchesOrderedItem(line, bracket: "[ ]")
  }

  private func isCompletedTask(_ line: String) -> Bool {
    line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ")
      || matchesOrderedItem(line, bracket: "[x]")
      || matchesOrderedItem(line, bracket: "[X]")
  }

  /// Returns `true` when `line` is an ordered list item (`1. <bracket> `) with the given bracket content.
  private func matchesOrderedItem(_ line: String, bracket: String) -> Bool {
    var idx = line.startIndex
    while idx < line.endIndex, line[idx].isNumber {
      idx = line.index(after: idx)
    }
    return idx > line.startIndex && line[idx...].hasPrefix(". \(bracket) ")
  }

  /// Strips the task list marker (`- [ ] `, `1. [x] `, etc.) from the beginning of a raw task line.
  private func stripTaskMarker(from line: String) -> String {
    for prefix in ["- [ ] ", "- [x] ", "- [X] "] where line.hasPrefix(prefix) {
      return String(line.dropFirst(prefix.count))
    }
    var idx = line.startIndex
    while idx < line.endIndex, line[idx].isNumber {
      idx = line.index(after: idx)
    }
    guard idx > line.startIndex else { return line }
    let rest = String(line[idx...])
    for suffix in [". [ ] ", ". [x] ", ". [X] "] where rest.hasPrefix(suffix) {
      return String(rest.dropFirst(suffix.count))
    }
    return line
  }

  private func isIndented(_ line: String) -> Bool {
    line.hasPrefix("    ") || line.hasPrefix("\t")
  }

  private func stripIndent(_ line: String) -> String {
    if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
    if line.hasPrefix("\t") { return String(line.dropFirst()) }
    return line
  }

  // MARK: - Task construction

  /// File-level context shared across all tasks parsed from a single file.
  private struct FileContext {
    let providerID: String
    let fileRelativePath: String
    let vaultName: String
    let list: TaskList
  }

  private func buildTaskItem(
    rawLine: String,
    lineNumber: Int,
    section: String?,
    notes: String?,
    context: FileContext
  ) -> TaskItem {
    var text = stripTaskMarker(from: rawLine)

    let priority = extractPriority(from: &text)
    let dueDate = extractDate(emoji: "📅", from: &text)
    let scheduledDate = extractDate(emoji: "⏰", from: &text)
    let startDate = extractDate(emoji: "🛫", from: &text)
    let title = text.trimmingCharacters(in: .whitespaces)

    return TaskItem(
      id: TaskRef(
        providerID: context.providerID,
        nativeID: "\(context.fileRelativePath):\(lineNumber)"
      ),
      title: title,
      notes: notes,
      format: .markdown,
      priority: priority,
      dueDate: dueDate,
      scheduledDate: scheduledDate,
      startDate: startDate,
      list: context.list,
      section: section,
      sourceURL: obsidianURL(vaultName: context.vaultName, filePath: context.fileRelativePath)
    )
  }

  /// Builds a ``TaskItem`` from a completed task line and extracts the `✅` completion date.
  private func buildCompletedEntry(
    rawLine: String,
    lineNumber: Int,
    section: String?,
    notes: String?,
    context: FileContext
  ) -> (item: TaskItem, completedAt: Date?) {
    var text = stripTaskMarker(from: rawLine)

    let completedAt = extractDate(emoji: "✅", from: &text)
    let priority = extractPriority(from: &text)
    let dueDate = extractDate(emoji: "📅", from: &text)
    let scheduledDate = extractDate(emoji: "⏰", from: &text)
    let startDate = extractDate(emoji: "🛫", from: &text)
    let title = text.trimmingCharacters(in: .whitespaces)

    let item = TaskItem(
      id: TaskRef(
        providerID: context.providerID,
        nativeID: "\(context.fileRelativePath):\(lineNumber)"
      ),
      title: title,
      notes: notes,
      format: .markdown,
      priority: priority,
      dueDate: dueDate,
      scheduledDate: scheduledDate,
      startDate: startDate,
      list: context.list,
      section: section,
      sourceURL: obsidianURL(vaultName: context.vaultName, filePath: context.fileRelativePath)
    )
    return (item, completedAt)
  }

  // MARK: - Field extraction

  private static let priorityEmojis: [(String, TaskPriority)] = [
    ("🔺", .highest),
    ("⏫", .high),
    ("🔼", .medium),
    ("🔽", .low),
    ("⏬", .lowest),
  ]

  /// Removes the first matching priority emoji from `text` and returns the mapped priority.
  private func extractPriority(from text: inout String) -> TaskPriority {
    for (emoji, priority) in Self.priorityEmojis {
      if let range = text.range(of: emoji) {
        text.removeSubrange(range)
        return priority
      }
    }
    return .none
  }

  /// Removes `emoji YYYY-MM-DD` from `text` and returns the parsed `Date`, or `nil` if absent/malformed.
  private func extractDate(emoji: String, from text: inout String) -> Date? {
    let pattern = "\(emoji) (\\d{4}-\\d{2}-\\d{2})"
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      let dateRange = Range(match.range(at: 1), in: text),
      let fullRange = Range(match.range, in: text)
    else { return nil }

    let dateString = String(text[dateRange])
    text.removeSubrange(fullRange)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.date(from: dateString)
  }

  private func obsidianURL(vaultName: String, filePath: String) -> URL? {
    // Strip .md extension per Obsidian convention
    let file =
      filePath.hasSuffix(".md") ? String(filePath.dropLast(3)) : filePath
    var components = URLComponents()
    components.scheme = "obsidian"
    components.host = "open"
    components.queryItems = [
      URLQueryItem(name: "vault", value: vaultName),
      URLQueryItem(name: "file", value: file),
    ]
    return components.url
  }
}
