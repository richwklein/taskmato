//
//  ObsidianTaskParser.swift
//  Taskmato
//

import Foundation

/// Parses the obsidian-tasks plugin format from raw markdown text into ``TaskItem`` values.
///
/// All file I/O is the caller's responsibility — this type accepts a plain `String` and
/// returns parsed tasks, making it straightforward to unit-test without a filesystem.
nonisolated struct ObsidianTaskParser: Sendable {

  // MARK: - Public interface

  /// The result of parsing a single markdown file for incomplete tasks.
  nonisolated struct ParseResult {
    /// Incomplete tasks found in the file, in source order.
    let items: [TaskItem]
    /// Text of the first H1 heading in the file, if any — used to name the ``TaskList``.
    let listName: String?
  }

  /// The result of parsing a single markdown file for completed tasks.
  nonisolated struct CompletedParseResult {
    /// Completed tasks, each with `completedAt` set from the `✅ YYYY-MM-DD` emoji when present.
    let entries: [TaskItem]
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
    providerID: ProviderID,
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
      isTarget: Self.isIncompleteTask,
      shouldSkip: Self.isCompletedTask
    )
    let items = raw.map { entry in
      buildTaskItem(
        rawLine: entry.rawLine, section: entry.section, notes: entry.notes, context: context,
        lineNumber: entry.lineNumber
      )
    }
    return ParseResult(items: items, listName: listName)
  }

  /// Parses all completed (`- [x]` / `- [X]`) tasks from `content`.
  ///
  /// Each ``TaskItem`` in the result has `completedAt` set from the `✅ YYYY-MM-DD` emoji
  /// when present, or `nil` when the date is absent.
  func parseCompleted(
    content: String,
    providerID: ProviderID,
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
      isTarget: Self.isCompletedTask,
      shouldSkip: Self.isIncompleteTask
    )
    let entries = raw.map { entry in
      buildCompletedEntry(
        rawLine: entry.rawLine, section: entry.section, notes: entry.notes, context: context,
        lineNumber: entry.lineNumber
      )
    }
    return CompletedParseResult(entries: entries, listName: listName)
  }

  // MARK: - State machine

  /// Raw task line collected by the state machine before field extraction.
  nonisolated private struct RawEntry {
    let rawLine: String
    let lineNumber: Int
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
    var pendingRaw: String?
    var pendingLineNumber: Int?
    var pendingSection: String?
    var notesBuffer: [String] = []

    func finalize() {
      guard let raw = pendingRaw else { return }
      let notes = notesBuffer.joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      collected.append(
        RawEntry(
          rawLine: raw,
          lineNumber: pendingLineNumber ?? 0,
          section: pendingSection,
          notes: notes.isEmpty ? nil : notes
        )
      )
      pendingRaw = nil
      pendingLineNumber = nil
      pendingSection = nil
      notesBuffer = []
    }

    for (offset, line) in lines.enumerated() {
      if let heading = Self.h1(line) {
        finalize()
        if listName == nil { listName = heading }
      } else if let heading = Self.subheading(line) {
        finalize()
        currentSection = heading
      } else if isTarget(line) {
        finalize()
        pendingRaw = line
        pendingLineNumber = offset + 1
        pendingSection = currentSection
      } else if shouldSkip(line) {
        finalize()
      } else if pendingRaw != nil, Self.isIndented(line) {
        notesBuffer.append(stripIndent(line))
      } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
        finalize()
      }
    }
    finalize()

    return (collected, listName)
  }

  // MARK: - Line classification

  /// Returns the heading text of `line` if it is an H1 (`# `) markdown heading, or `nil`.
  ///
  /// Shared with ``ObsidianProvider``'s write-side section-block boundary detection.
  static func h1(_ line: String) -> String? {
    guard line.hasPrefix("# ") else { return nil }
    return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
  }

  /// Returns the heading text of `line` if it is a `##`–`######` markdown subheading, or `nil`.
  ///
  /// Shared with ``ObsidianProvider``'s write-side section matching so both read and write use
  /// the exact same heading-classification rule.
  static func subheading(_ line: String) -> String? {
    guard
      line.hasPrefix("## ") || line.hasPrefix("### ") || line.hasPrefix("#### ")
        || line.hasPrefix("##### ") || line.hasPrefix("###### ")
    else { return nil }
    if let spaceIdx = line.firstIndex(of: " ") {
      return String(line[line.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
    }
    return nil
  }

  /// Returns `true` if `line` is an incomplete task list item (`- [ ] ` or `N. [ ] `).
  ///
  /// Shared with ``ObsidianProvider``'s write-side task-line lookup so both read and write agree
  /// on what counts as a task line.
  static func isIncompleteTask(_ line: String) -> Bool {
    line.hasPrefix("- [ ] ") || matchesOrderedItem(line, bracket: "[ ]")
  }

  /// Returns `true` if `line` is a completed task list item (`- [x] `/`- [X] ` or `N. [x/X] `).
  static func isCompletedTask(_ line: String) -> Bool {
    line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ")
      || matchesOrderedItem(line, bracket: "[x]")
      || matchesOrderedItem(line, bracket: "[X]")
  }

  /// Returns `true` when `line` is an ordered list item (`1. <bracket> `) with the given bracket content.
  private static func matchesOrderedItem(_ line: String, bracket: String) -> Bool {
    var idx = line.startIndex
    while idx < line.endIndex, line[idx].isNumber {
      idx = line.index(after: idx)
    }
    return idx > line.startIndex && line[idx...].hasPrefix(". \(bracket) ")
  }

  /// Returns `true` if `line` is indented (a task's note/continuation line).
  ///
  /// Shared with ``ObsidianProvider``'s write-side note-block detection so both read and write
  /// agree on what counts as a task's trailing notes.
  static func isIndented(_ line: String) -> Bool {
    line.hasPrefix("    ") || line.hasPrefix("\t")
  }

  private func stripIndent(_ line: String) -> String {
    if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
    if line.hasPrefix("\t") { return String(line.dropFirst()) }
    return line
  }

  // MARK: - Task construction

  /// File-level context shared across all tasks parsed from a single file.
  nonisolated private struct FileContext {
    let providerID: ProviderID
    let fileRelativePath: String
    let vaultName: String
    let list: TaskList
  }

  private func buildTaskItem(
    rawLine: String,
    section: String?,
    notes: String?,
    context: FileContext,
    lineNumber: Int
  ) -> TaskItem {
    var text = ObsidianTaskIdentity.stripTaskMarker(from: rawLine)

    let priority = extractPriority(from: &text)
    let dueDate = extractDate(emoji: "📅", from: &text)
    let scheduledDate = extractDate(emoji: "⏰", from: &text)
    let startDate = extractDate(emoji: "🛫", from: &text)
    let title = text.trimmingCharacters(in: .whitespaces)

    return TaskItem(
      id: TaskRef(
        providerID: context.providerID,
        nativeID: ObsidianTaskIdentity.nativeID(
          fileRelativePath: context.fileRelativePath,
          rawLine: rawLine,
          lineNumber: lineNumber
        )
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
      sourceURL: obsidianURL(vaultName: context.vaultName, filePath: context.fileRelativePath),
      createdAt: nil
    )
  }

  /// Builds a ``TaskItem`` from a completed task line, setting `completedAt` from the `✅` emoji.
  private func buildCompletedEntry(
    rawLine: String,
    section: String?,
    notes: String?,
    context: FileContext,
    lineNumber: Int
  ) -> TaskItem {
    var text = ObsidianTaskIdentity.stripTaskMarker(from: rawLine)

    let completedAt = extractDate(emoji: "✅", from: &text)
    let priority = extractPriority(from: &text)
    let dueDate = extractDate(emoji: "📅", from: &text)
    let scheduledDate = extractDate(emoji: "⏰", from: &text)
    let startDate = extractDate(emoji: "🛫", from: &text)
    let title = text.trimmingCharacters(in: .whitespaces)

    return TaskItem(
      id: TaskRef(
        providerID: context.providerID,
        nativeID: ObsidianTaskIdentity.nativeID(
          fileRelativePath: context.fileRelativePath,
          rawLine: rawLine,
          lineNumber: lineNumber
        )
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
      sourceURL: obsidianURL(vaultName: context.vaultName, filePath: context.fileRelativePath),
      completedAt: completedAt,
      createdAt: nil
    )
  }

  // MARK: - Field extraction

  /// Priority emoji, in match-priority order. Shared with ``ObsidianTaskLineFormatter`` so read
  /// and write use the exact same emoji↔priority mapping.
  nonisolated static let priorityEmojis: [(String, TaskPriority)] = [
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

/// Builds and parses Obsidian task references from vault-relative path plus task content.
nonisolated enum ObsidianTaskIdentity {
  private static let fingerprintSeparator = "#fp="
  private static let lineSeparator = "#line="

  /// Components parsed from a current or legacy native ID.
  struct Components: Sendable {
    let fileRelativePath: String
    let fingerprint: String?
    let lineNumber: Int?
  }

  /// Returns the native ID for a task line in a vault-relative file.
  static func nativeID(fileRelativePath: String, rawLine: String, lineNumber: Int) -> String {
    "\(fileRelativePath)\(fingerprintSeparator)\(fingerprint(for: rawLine))\(lineSeparator)\(lineNumber)"
  }

  /// Parses current fingerprint IDs and the pre-fingerprint `path:line` format.
  static func parseNativeID(_ nativeID: String) -> Components? {
    if let range = nativeID.range(of: fingerprintSeparator) {
      let fileRelativePath = String(nativeID[..<range.lowerBound])
      let suffix = String(nativeID[range.upperBound...])
      let parts = suffix.split(separator: "#", maxSplits: 1).map(String.init)
      let fingerprint = parts.first
      let linePart = parts.dropFirst().first
      let lineNumber: Int? = {
        guard let linePart, linePart.hasPrefix(String(lineSeparator.dropFirst())) else {
          return nil
        }
        return Int(linePart.dropFirst(lineSeparator.dropFirst().count))
      }()
      guard !fileRelativePath.isEmpty, let fingerprint, !fingerprint.isEmpty else { return nil }
      return Components(
        fileRelativePath: fileRelativePath, fingerprint: fingerprint, lineNumber: lineNumber)
    }

    guard let separator = nativeID.lastIndex(of: ":"),
      let lineNumber = Int(nativeID[nativeID.index(after: separator)...])
    else { return nil }
    let fileRelativePath = String(nativeID[..<separator])
    guard !fileRelativePath.isEmpty else { return nil }
    return Components(fileRelativePath: fileRelativePath, fingerprint: nil, lineNumber: lineNumber)
  }

  /// Returns the line content without its unordered or ordered checkbox marker.
  static func stripTaskMarker(from line: String) -> String {
    for prefix in ["- [ ] ", "- [x] ", "- [X] "] where line.hasPrefix(prefix) {
      return String(line.dropFirst(prefix.count))
    }
    var idx = line.startIndex
    while idx < line.endIndex, line[idx].isNumber { idx = line.index(after: idx) }
    guard idx > line.startIndex else { return line }
    let rest = String(line[idx...])
    for suffix in [". [ ] ", ". [x] ", ". [X] "] where rest.hasPrefix(suffix) {
      return String(rest.dropFirst(suffix.count))
    }
    return line
  }

  /// Returns a stable hash for the task content after dropping its checkbox marker.
  static func fingerprint(for rawLine: String) -> String {
    stableHash(normalizedContent(from: rawLine))
  }

  private static func normalizedContent(from rawLine: String) -> String {
    stripTaskMarker(from: rawLine)
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func stableHash(_ content: String) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in content.utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100_0000_01b3
    }
    return String(format: "%016llx", hash)
  }
}
