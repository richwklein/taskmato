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

  /// The result of parsing a single markdown file.
  struct ParseResult {
    /// Incomplete tasks found in the file, in source order.
    let items: [TaskItem]
    /// Completed tasks found in the file, in source order.
    let completedItems: [TaskItem]
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
    let lines = content.components(separatedBy: "\n")
    let context = FileContext(
      providerID: providerID,
      fileRelativePath: fileRelativePath,
      vaultName: vaultName,
      list: list
    )
    var items: [TaskItem] = []
    var completedItems: [TaskItem] = []
    var listName: String?

    // Mutable parse state
    var currentSection: String?
    var pendingLine: Int?
    var pendingRaw: String?
    var pendingSection: String?
    var pendingIsCompleted: Bool = false
    var notesBuffer: [String] = []

    func finalizeTask() {
      guard let lineNumber = pendingLine, let rawLine = pendingRaw else { return }
      let joined = notesBuffer.joined(separator: "\n")
      let notes = joined.trimmingCharacters(in: .whitespacesAndNewlines)
      let item = buildTaskItem(
        rawLine: rawLine,
        lineNumber: lineNumber,
        section: pendingSection,
        notes: notes.isEmpty ? nil : notes,
        context: context
      )
      if pendingIsCompleted { completedItems.append(item) } else { items.append(item) }
      (pendingLine, pendingRaw, pendingSection, pendingIsCompleted, notesBuffer) = (
        nil, nil, nil, false, []
      )
    }

    for (zeroIndex, line) in lines.enumerated() {
      let lineNumber = zeroIndex + 1
      if let headingText = h1(line) {
        finalizeTask()
        if listName == nil { listName = headingText }
      } else if let headingText = subheading(line) {
        finalizeTask()
        currentSection = headingText
      } else if isIncompleteTask(line) {
        finalizeTask()
        (pendingLine, pendingRaw, pendingSection) = (lineNumber, line, currentSection)
      } else if isCompletedTask(line) {
        finalizeTask()
        (pendingLine, pendingRaw, pendingSection, pendingIsCompleted) = (
          lineNumber, line, currentSection, true
        )
      } else if pendingLine != nil, isIndented(line) {
        notesBuffer.append(stripIndent(line))
      } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
        finalizeTask()
      }
    }

    finalizeTask()

    return ParseResult(items: items, completedItems: completedItems, listName: listName)
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
    line.hasPrefix("- [ ] ")
  }

  private func isCompletedTask(_ line: String) -> Bool {
    line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ")
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
    var text = String(rawLine.dropFirst(6))  // strip "- [ ] " or "- [x] " (both 6 chars)

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
