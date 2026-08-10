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

  /// The style to use for a newly written task line.
  private enum TaskLineStyle {
    case unordered
    case ordered(Int)

    nonisolated var orderedNumber: Int? {
      switch self {
      case .unordered:
        return nil
      case .ordered(let number):
        return number
      }
    }
  }

  /// The captured state needed to apply an update or move to a task.
  private struct UpdateTaskContext {
    let draft: TaskDraft
    let ref: String
    let identity: ObsidianTaskIdentity.Components
    let currentRelPath: String
    let targetRelPath: String
    let vaultURL: URL
  }

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
  /// file. Targets `draft.listID` if set, otherwise the configured default or first matching file.
  @discardableResult
  func addTask(_ draft: TaskDraft) async throws -> TaskItem {
    guard let vaultURL else {
      throw ObsidianProviderError.vaultNotConfigured
    }
    let availableLists = try await lists()
    let relPath: String
    if let explicitListID = draft.listID {
      guard availableLists.contains(where: { $0.id == explicitListID }) else {
        throw ObsidianProviderError.listNotFound(explicitListID)
      }
      relPath = explicitListID
    } else if let defaultListID {
      if availableLists.contains(where: { $0.id == defaultListID }) {
        relPath = defaultListID
      } else if let firstList = availableLists.first {
        relPath = firstList.id
      } else {
        throw ObsidianProviderError.noListAvailable
      }
    } else if let firstList = availableLists.first {
      relPath = firstList.id
    } else {
      throw ObsidianProviderError.noListAvailable
    }
    let fileURL = vaultURL.appending(path: relPath)

    let (insertedLineNumber, taskLine) = try await Task.detached(
      priority: .userInitiated
    ) { [weak self] in
      guard let self else { throw ObsidianProviderError.vaultNotConfigured }
      return try self.withVaultAccess(vaultURL) { _ in
        var lines = try String(contentsOf: fileURL, encoding: .utf8)
          .components(separatedBy: "\n")
        let wasEmptyFile = lines == [""]
        let insertionIndex = try Self.insertionIndex(
          forSection: draft.section, in: lines, list: relPath
        )
        let style = Self.style(forInsertionAt: insertionIndex, in: lines, section: draft.section)
        let (taskLine, noteLines) = Self.formatLines(for: draft, orderedNumber: style.orderedNumber)
        lines.insert(contentsOf: [taskLine] + noteLines, at: insertionIndex)
        if wasEmptyFile { lines.removeLast() }
        let updated = lines.joined(separator: "\n")
        try Data(updated.utf8).write(to: fileURL, options: [])
        return (insertionIndex + 1, taskLine)
      }
    }.value

    let taskList = TaskList(id: relPath, providerID: Self.providerID, name: "")
    // The fingerprint is deterministic from the exact line text we just wrote, so the expected
    // ID can be computed directly instead of re-deriving it from the re-read task — this is the
    // same identity scheme ``ObsidianTaskParser`` uses when it re-parses the file.
    let expectedNativeID = ObsidianTaskIdentity.nativeID(
      fileRelativePath: relPath, rawLine: taskLine, lineNumber: insertedLineNumber
    )
    guard
      let item = try await tasks(in: taskList).first(where: { $0.id.nativeID == expectedNativeID }
      )
    else {
      throw ObsidianProviderError.taskNotFound(expectedNativeID)
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
    guard let identity = ObsidianTaskIdentity.parseNativeID(ref.nativeID) else {
      throw ObsidianProviderError.invalidNativeID(ref.nativeID)
    }
    let currentRelPath = identity.fileRelativePath
    let targetRelPath = draft.listID ?? currentRelPath

    try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      try self.withVaultAccess(vaultURL) { _ in
        try Self.writeUpdatedTask(
          context: UpdateTaskContext(
            draft: draft,
            ref: ref.nativeID,
            identity: identity,
            currentRelPath: currentRelPath,
            targetRelPath: targetRelPath,
            vaultURL: vaultURL
          )
        )
      }
    }.value
  }

  /// Removes the task identified by `ref`, including its trailing indented note lines.
  func deleteTask(_ ref: TaskRef) async throws {
    guard let vaultURL else {
      throw ObsidianProviderError.vaultNotConfigured
    }
    guard let identity = ObsidianTaskIdentity.parseNativeID(ref.nativeID) else {
      throw ObsidianProviderError.invalidNativeID(ref.nativeID)
    }
    let fileURL = vaultURL.appending(path: identity.fileRelativePath)

    try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      try self.withVaultAccess(vaultURL) { _ in
        var lines = try String(contentsOf: fileURL, encoding: .utf8)
          .components(separatedBy: "\n")
        let (taskIndex, noteEndIndex) = try Self.lineRange(
          for: identity, in: lines, ref: ref.nativeID
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
    formatLines(for: draft, orderedNumber: nil)
  }

  /// Builds the task line and note lines for `draft` via ``ObsidianTaskLineFormatter``.
  private nonisolated static func formatLines(
    for draft: TaskDraft,
    orderedNumber: Int?
  ) -> (taskLine: String, noteLines: [String]) {
    let formatter = ObsidianTaskLineFormatter()
    let taskLine = formatter.formatLine(
      title: draft.title,
      orderedNumber: orderedNumber,
      priority: draft.priority,
      dueDate: draft.dueDate
    )
    return (taskLine, formatter.formatNoteLines(draft.notes))
  }

  /// Returns the style for a new task inserted at `insertionIndex`.
  ///
  /// New tasks use the nearest preceding recognized task within the destination section, or the
  /// nearest preceding recognized task anywhere in the file when `section` is `nil`.
  private nonisolated static func style(
    forInsertionAt insertionIndex: Int,
    in lines: [String],
    section: String?
  ) -> TaskLineStyle {
    var lineIndex = insertionIndex - 1
    while lineIndex >= 0 {
      let line = lines[lineIndex]
      if ObsidianTaskParser.isIncompleteTask(line) || ObsidianTaskParser.isCompletedTask(line) {
        return style(forInsertedTaskLine: line)
      }
      if section != nil {
        if ObsidianTaskParser.h1(line) != nil || ObsidianTaskParser.subheading(line) != nil {
          break
        }
      }
      lineIndex -= 1
    }
    return .unordered
  }

  /// Returns the style for rewriting `line` in place.
  ///
  /// In-place edits preserve the exact list style and number already present on the line.
  private nonisolated static func style(forTaskLine line: String) -> TaskLineStyle {
    guard ObsidianTaskParser.isOrderedTask(line) else { return .unordered }
    guard let orderedNumber = ObsidianTaskParser.orderedTaskNumber(line) else {
      return .ordered(1)
    }
    return .ordered(orderedNumber)
  }

  /// Returns the style for a new line following `line`, advancing ordered numbering when needed.
  private nonisolated static func style(forInsertedTaskLine line: String) -> TaskLineStyle {
    guard ObsidianTaskParser.isOrderedTask(line) else { return .unordered }
    guard let orderedNumber = ObsidianTaskParser.orderedTaskNumber(line) else {
      return .ordered(1)
    }
    return .ordered(orderedNumber == Int.max ? 1 : orderedNumber + 1)
  }

  /// Applies an update or move to the task identified by `ref`.
  private nonisolated static func writeUpdatedTask(context: UpdateTaskContext) throws {
    let sourceFileURL = context.vaultURL.appending(path: context.currentRelPath)
    var sourceLines = try String(contentsOf: sourceFileURL, encoding: .utf8)
      .components(separatedBy: "\n")
    let (taskIndex, noteEndIndex) = try Self.lineRange(
      for: context.identity, in: sourceLines, ref: context.ref
    )
    let currentSection = Self.section(ofLineAt: taskIndex, in: sourceLines)

    if context.targetRelPath == context.currentRelPath, context.draft.section == currentSection {
      let style = Self.style(forTaskLine: sourceLines[taskIndex])
      let (taskLine, noteLines) = Self.formatLines(
        for: context.draft,
        orderedNumber: style.orderedNumber
      )
      sourceLines.replaceSubrange(taskIndex..<noteEndIndex, with: [taskLine] + noteLines)
      try Data(sourceLines.joined(separator: "\n").utf8).write(to: sourceFileURL, options: [])
      return
    }

    sourceLines.removeSubrange(taskIndex..<noteEndIndex)

    if context.targetRelPath == context.currentRelPath {
      let insertionIndex = try Self.insertionIndex(
        forSection: context.draft.section, in: sourceLines, list: context.targetRelPath
      )
      let style = Self.style(
        forInsertionAt: insertionIndex,
        in: sourceLines,
        section: context.draft.section
      )
      let (taskLine, noteLines) = Self.formatLines(
        for: context.draft,
        orderedNumber: style.orderedNumber
      )
      sourceLines.insert(contentsOf: [taskLine] + noteLines, at: insertionIndex)
      try Data(sourceLines.joined(separator: "\n").utf8).write(to: sourceFileURL, options: [])
      return
    }

    try Data(sourceLines.joined(separator: "\n").utf8).write(to: sourceFileURL, options: [])

    let destFileURL = context.vaultURL.appending(path: context.targetRelPath)
    var destLines = try String(contentsOf: destFileURL, encoding: .utf8)
      .components(separatedBy: "\n")
    let insertionIndex = try Self.insertionIndex(
      forSection: context.draft.section, in: destLines, list: context.targetRelPath
    )
    let style = Self.style(
      forInsertionAt: insertionIndex,
      in: destLines,
      section: context.draft.section
    )
    let (taskLine, noteLines) = Self.formatLines(
      for: context.draft,
      orderedNumber: style.orderedNumber
    )
    destLines.insert(contentsOf: [taskLine] + noteLines, at: insertionIndex)
    try Data(destLines.joined(separator: "\n").utf8).write(to: destFileURL, options: [])
  }

  // MARK: - Write-side section/line-range helpers

  /// Resolves the task line identified by `identity` in `lines`, and returns its index plus the
  /// index just past its trailing indented note lines.
  ///
  /// Matches by content fingerprint rather than trusting the persisted line number as ground
  /// truth — the file may have gained or lost lines elsewhere since `ref` was captured. Legacy
  /// refs from before the fingerprint scheme (no `fingerprint` component) fall back to matching
  /// by line number alone. Mirrors ``ObsidianProvider``'s read-side `matches`/`resolve` and the
  /// `complete`/`reopen` rewrite path's own fingerprint matching.
  private nonisolated static func lineRange(
    for identity: ObsidianTaskIdentity.Components,
    in lines: [String],
    ref nativeID: String
  ) throws -> (taskIndex: Int, noteEndIndex: Int) {
    let candidates = lines.indices.filter { index in
      guard
        ObsidianTaskParser.isIncompleteTask(lines[index])
          || ObsidianTaskParser.isCompletedTask(lines[index])
      else { return false }
      if let fingerprint = identity.fingerprint {
        return ObsidianTaskIdentity.fingerprint(for: lines[index]) == fingerprint
      }
      return identity.lineNumber == index + 1
    }
    let taskIndex = try selectIndex(candidates, lineNumber: identity.lineNumber, ref: nativeID)
    var noteEnd = taskIndex + 1
    while noteEnd < lines.count, ObsidianTaskParser.isIndented(lines[noteEnd]) {
      noteEnd += 1
    }
    return (taskIndex, noteEnd)
  }

  /// Picks the single matching line index from `candidates`, disambiguating multiple
  /// identical-content matches by proximity to `lineNumber` — the same tie-breaking rule
  /// ``ObsidianProvider``'s `complete`/`reopen` rewrite path uses for duplicate fingerprints.
  private nonisolated static func selectIndex(
    _ candidates: [Int], lineNumber: Int?, ref nativeID: String
  ) throws -> Int {
    guard !candidates.isEmpty else { throw ObsidianProviderError.taskNotFound(nativeID) }
    guard candidates.count > 1 else { return candidates[0] }
    guard let lineNumber else { throw ObsidianProviderError.ambiguousTaskRef(nativeID) }
    let ranked = candidates.sorted { abs($0 + 1 - lineNumber) < abs($1 + 1 - lineNumber) }
    let bestDistance = abs(ranked[0] + 1 - lineNumber)
    guard ranked.dropFirst().first.map({ abs($0 + 1 - lineNumber) > bestDistance }) ?? true
    else {
      throw ObsidianProviderError.ambiguousTaskRef(nativeID)
    }
    return ranked[0]
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
