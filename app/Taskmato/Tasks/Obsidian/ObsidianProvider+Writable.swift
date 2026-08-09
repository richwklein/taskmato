//
//  ObsidianProvider+Writable.swift
//  Taskmato
//

import Foundation

/// ``TaskProvider/sections(in:)`` and ``WritableTaskProvider`` conformance for
/// ``ObsidianProvider``: heading discovery, task creation, editing, and deletion against vault
/// files, plus the section-boundary and line-range helpers that let a write target a specific
/// markdown heading (see ``insertionIndex(forSection:in:list:)``).
///
/// Split into its own file — alongside ``ObsidianProvider``'s existing read/`ClosableTaskProvider`
/// logic — purely to keep both files under the project's size lint limits; there is no
/// architectural boundary between the two.
extension ObsidianProvider {

  // MARK: - TaskProvider

  /// Returns every heading in `list`'s file, in document order, regardless of whether it
  /// currently has any tasks under it — unlike deriving sections from ``tasks(in:)`` results,
  /// this surfaces headings a user could target even if nothing has been filed under them yet.
  func sections(in list: TaskList) async throws -> [String] {
    guard let vaultURL else { return [] }
    let fileURL = vaultURL.appending(path: list.id)
    return try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return [] }
      return try self.withVaultAccess(vaultURL) { _ in
        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var seen = Set<String>()
        return content.components(separatedBy: "\n")
          .compactMap { ObsidianTaskParser.subheading($0) }
          .filter { seen.insert($0).inserted }
      }
    }.value
  }

  // MARK: - WritableTaskProvider

  /// Persists `listID` (a vault-relative file path) as the default target for new tasks.
  ///
  /// Validated against `lists()` so the default stays consistent with what the sidebar shows.
  func setDefaultList(_ listID: String) async throws {
    guard try await lists().contains(where: { $0.id == listID }) else {
      throw ObsidianProviderError.listNotFound(listID)
    }
    defaultListOverride = listID
  }

  /// Appends a new task line to the target file.
  ///
  /// When `draft.section` is given, the line is inserted as the last item in that heading's
  /// existing task block (a continuation of that section's list), rather than at the end of the
  /// file. Targets `draft.listID` if set, otherwise ``defaultListID``.
  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem {
    guard let vaultURL else {
      throw ObsidianProviderError.vaultNotConfigured
    }
    guard let relPath = draft.listID ?? defaultListID else {
      throw ObsidianProviderError.listNotFound("")
    }
    let fileURL = vaultURL.appending(path: relPath)
    let (taskLine, noteLines) = Self.formatLines(for: draft)

    let insertedLineNumber = try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { throw ObsidianProviderError.vaultNotConfigured }
      return try self.withVaultAccess(vaultURL) { _ in
        var lines = try String(contentsOf: fileURL, encoding: .utf8)
          .components(separatedBy: "\n")
        let insertionIndex = try Self.insertionIndex(
          forSection: draft.section, in: lines, list: relPath
        )
        lines.insert(contentsOf: [taskLine] + noteLines, at: insertionIndex)
        let updated = lines.joined(separator: "\n")
        try Data(updated.utf8).write(to: fileURL, options: [])
        return insertionIndex + 1
      }
    }.value

    let taskList = TaskList(id: relPath, providerID: Self.providerID, name: "")
    let nativeID = "\(relPath):\(insertedLineNumber)"
    guard let item = try await tasks(in: taskList).first(where: { $0.id.nativeID == nativeID })
    else {
      throw ObsidianProviderError.taskNotFound(nativeID)
    }
    return item
  }

  /// Applies `draft` to the task identified by `ref`.
  ///
  /// If `draft.listID`/`draft.section` differ from the task's current file/section, the task is
  /// moved: removed from its current location and inserted at the destination using the same
  /// section-continuation rule as ``addTask(_:)``. Otherwise the line is rewritten in place.
  func updateTask(_ ref: TaskRef, draft: TaskDraft) async throws {
    guard let vaultURL else {
      throw ObsidianProviderError.vaultNotConfigured
    }
    let (currentRelPath, lineNumber) = try Self.parseNativeID(ref.nativeID)
    let targetRelPath = draft.listID ?? currentRelPath
    let (taskLine, noteLines) = Self.formatLines(for: draft)

    try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      try self.withVaultAccess(vaultURL) { _ in
        let sourceFileURL = vaultURL.appending(path: currentRelPath)
        var sourceLines = try String(contentsOf: sourceFileURL, encoding: .utf8)
          .components(separatedBy: "\n")
        let (taskIndex, noteEndIndex) = try Self.lineRange(
          atLine: lineNumber, in: sourceLines, ref: ref.nativeID
        )
        let currentSection = Self.section(ofLineAt: taskIndex, in: sourceLines)

        if targetRelPath == currentRelPath, draft.section == currentSection {
          sourceLines.replaceSubrange(taskIndex..<noteEndIndex, with: [taskLine] + noteLines)
          try Data(sourceLines.joined(separator: "\n").utf8).write(to: sourceFileURL, options: [])
          return
        }

        sourceLines.removeSubrange(taskIndex..<noteEndIndex)

        if targetRelPath == currentRelPath {
          let insertionIndex = try Self.insertionIndex(
            forSection: draft.section, in: sourceLines, list: targetRelPath
          )
          sourceLines.insert(contentsOf: [taskLine] + noteLines, at: insertionIndex)
          try Data(sourceLines.joined(separator: "\n").utf8).write(to: sourceFileURL, options: [])
        } else {
          try Data(sourceLines.joined(separator: "\n").utf8).write(to: sourceFileURL, options: [])

          let destFileURL = vaultURL.appending(path: targetRelPath)
          var destLines = try String(contentsOf: destFileURL, encoding: .utf8)
            .components(separatedBy: "\n")
          let insertionIndex = try Self.insertionIndex(
            forSection: draft.section, in: destLines, list: targetRelPath
          )
          destLines.insert(contentsOf: [taskLine] + noteLines, at: insertionIndex)
          try Data(destLines.joined(separator: "\n").utf8).write(to: destFileURL, options: [])
        }
      }
    }.value
  }

  /// Removes the task identified by `ref`, including its trailing indented note lines.
  func deleteTask(_ ref: TaskRef) async throws {
    guard let vaultURL else {
      throw ObsidianProviderError.vaultNotConfigured
    }
    let (relPath, lineNumber) = try Self.parseNativeID(ref.nativeID)
    let fileURL = vaultURL.appending(path: relPath)

    try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      try self.withVaultAccess(vaultURL) { _ in
        var lines = try String(contentsOf: fileURL, encoding: .utf8)
          .components(separatedBy: "\n")
        let (taskIndex, noteEndIndex) = try Self.lineRange(
          atLine: lineNumber, in: lines, ref: ref.nativeID
        )
        lines.removeSubrange(taskIndex..<noteEndIndex)
        try Data(lines.joined(separator: "\n").utf8).write(to: fileURL, options: [])
      }
    }.value
  }

  /// Builds the task line and note lines for `draft` via ``ObsidianTaskLineFormatter``.
  private nonisolated static func formatLines(for draft: TaskDraft) -> (
    taskLine: String, noteLines: [String]
  ) {
    let formatter = ObsidianTaskLineFormatter()
    let taskLine = formatter.formatLine(
      title: draft.title,
      priority: draft.priority,
      dueDate: draft.dueDate
    )
    return (taskLine, formatter.formatNoteLines(draft.notes))
  }

  // MARK: - Write-side section/line-range helpers

  /// Splits `nativeID` into its vault-relative path and 1-based line number.
  private nonisolated static func parseNativeID(_ nativeID: String) throws -> (
    relPath: String, lineNumber: Int
  ) {
    let parts = nativeID.split(separator: ":", maxSplits: 1)
    guard parts.count == 2, let lineNumber = Int(parts[1]) else {
      throw ObsidianProviderError.invalidNativeID(nativeID)
    }
    return (String(parts[0]), lineNumber)
  }

  /// Resolves the task line at `lineNumber` (1-based) in `lines`, verifying it's still a task
  /// line, and returns its index plus the index just past its trailing indented note lines.
  ///
  /// Unlike `complete`/`reopen`'s checkbox-swap fallback, there's no reliable secondary key to
  /// re-locate a moved line here (`TaskRef` carries no title), so a stale line number surfaces
  /// as `.taskNotFound` rather than being silently relocated by a file-wide scan.
  private nonisolated static func lineRange(
    atLine lineNumber: Int,
    in lines: [String],
    ref nativeID: String
  ) throws -> (taskIndex: Int, noteEndIndex: Int) {
    let index = lineNumber - 1
    guard index >= 0, index < lines.count,
      ObsidianTaskParser.isIncompleteTask(lines[index])
        || ObsidianTaskParser.isCompletedTask(
          lines[index])
    else {
      throw ObsidianProviderError.taskNotFound(nativeID)
    }
    var noteEnd = index + 1
    while noteEnd < lines.count, ObsidianTaskParser.isIndented(lines[noteEnd]) {
      noteEnd += 1
    }
    return (index, noteEnd)
  }

  /// Returns the section (nearest preceding subheading) for the line at `index`, scanning
  /// backward until a heading of any level or the start of the file.
  private nonisolated static func section(ofLineAt index: Int, in lines: [String]) -> String? {
    var lineIndex = index - 1
    while lineIndex >= 0 {
      if let heading = ObsidianTaskParser.subheading(lines[lineIndex]) { return heading }
      if ObsidianTaskParser.h1(lines[lineIndex]) != nil { return nil }
      lineIndex -= 1
    }
    return nil
  }

  /// Computes the insertion index for a new task line targeting `section` within `lines`.
  ///
  /// `nil` section inserts at the end of the file (before a single trailing blank line, if
  /// present). A given section inserts after the last non-blank line in that heading's block (or
  /// immediately after the heading if the block is empty), so the new task continues that
  /// section's existing list rather than landing at end of file. The first heading whose text
  /// matches `section` wins on duplicate headings, matching the parser's own read-side behavior.
  private nonisolated static func insertionIndex(
    forSection section: String?,
    in lines: [String],
    list: String
  ) throws -> Int {
    guard let section else {
      return (lines.last?.isEmpty ?? false) ? max(lines.count - 1, 0) : lines.count
    }

    guard
      let headingIndex = lines.firstIndex(where: { ObsidianTaskParser.subheading($0) == section })
    else {
      throw ObsidianProviderError.sectionNotFound(list: list, section: section)
    }

    var blockEnd = lines.count
    for lineIndex in (headingIndex + 1)..<lines.count {
      let line = lines[lineIndex]
      let isHeading =
        ObsidianTaskParser.h1(line) != nil || ObsidianTaskParser.subheading(line) != nil
      if isHeading {
        blockEnd = lineIndex
        break
      }
    }

    var lastContentIndex = headingIndex
    var lineIndex = blockEnd - 1
    while lineIndex > headingIndex {
      if !lines[lineIndex].trimmingCharacters(in: .whitespaces).isEmpty {
        lastContentIndex = lineIndex
        break
      }
      lineIndex -= 1
    }
    return lastContentIndex + 1
  }
}
