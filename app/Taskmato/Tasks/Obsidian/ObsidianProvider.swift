//
//  ObsidianProvider.swift
//  Taskmato
//

import AppKit
import CoreServices
import Foundation
import SwiftUI

/// A task provider that reads incomplete tasks from all matching markdown files in an Obsidian vault.
///
/// Vault directory access uses a security-scoped bookmark persisted in ``UserDefaults``.
/// The provider is read-write: `complete(_:)` rewrites the task line from `- [ ]` to `- [x]`
/// in place; `reopen(_:)` reverses the operation; `completedTasks()` scans the vault for
/// `- [x]` lines and returns them sorted by their `✅` completion date.
///
/// - Note: `observe()` watches the vault recursively using `FSEventStreamCreate`. Rapid
///   change notifications are coalesced by a 250 ms debounce before a rescan is triggered.
@Observable
@MainActor
final class ObsidianProvider: ClosableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  static let providerID = "obsidian"

  let id: String = ObsidianProvider.providerID
  let displayName: String = "Obsidian"
  let icon: String = "book.closed"
  let entitlement: ProviderEntitlement = .free

  /// The user-selected vault directory, resolved from the stored security-scoped bookmark.
  private(set) var vaultURL: URL?

  /// Glob patterns (relative to vault root) used to select which markdown files are scanned.
  /// Supports `{year}`, `{YYYY}`, `{month}`, `{MM}`, `{week}`, `{ww}`, `{day}`, `{DD}` tokens.
  private(set) var filePatterns: [String]

  /// Human-readable vault name derived from the last path component of `vaultURL`.
  var vaultName: String { vaultURL?.lastPathComponent ?? "" }

  /// Whether the user has selected a vault directory.
  var isConfigured: Bool { vaultURL != nil }

  private let defaults: UserDefaults
  private let parser = ObsidianTaskParser()
  private var streamContinuation: AsyncStream<[TaskItem]>.Continuation?
  private var fsEventStream: FSEventStreamRef?
  private let debouncer = Debouncer()

  private static let bookmarkKey = "obsidian.vaultBookmark"
  private static let patternsKey = "obsidian.filePatterns"
  private static let defaultPatterns = ["**/*.md"]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.filePatterns =
      defaults.array(forKey: Self.patternsKey) as? [String] ?? Self.defaultPatterns
    restoreVaultBookmark()
  }

  /// Creates a pre-configured provider for unit tests, bypassing the UserDefaults bookmark lookup.
  init(
    defaults: UserDefaults,
    vaultURL: URL?,
    filePatterns: [String] = ObsidianProvider.defaultPatterns
  ) {
    self.defaults = defaults
    self.filePatterns = filePatterns
    self.vaultURL = vaultURL
  }

  // MARK: - TaskProvider

  /// No-op — vault selection is initiated by the user in Settings.
  func authorize() async throws {}

  /// Returns one ``TaskList`` per matching markdown file.
  ///
  /// The list name is the file's H1 heading if present, otherwise the filename without extension.
  func lists() async throws -> [TaskList] {
    guard let vaultURL else { return [] }
    let patterns = filePatterns
    return try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return [] }
      return try self.withVaultAccess(vaultURL) { url in
        let files = self.scanMarkdownFiles(in: url, patterns: patterns)
        return files.map { fileURL in
          let relPath = self.relativePath(for: fileURL, relativeTo: url)
          let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
          let result = self.parser.parse(
            content: content,
            providerID: Self.providerID,
            fileRelativePath: relPath,
            vaultName: url.lastPathComponent,
            list: TaskList(id: relPath, providerID: Self.providerID, name: "")
          )
          let name = result.listName ?? fileURL.deletingPathExtension().lastPathComponent
          return TaskList(id: relPath, providerID: Self.providerID, name: name)
        }
      }
    }.value
  }

  /// Returns incomplete tasks from all matching files, or from a single file if `list` is provided.
  func tasks(in list: TaskList?) async throws -> [TaskItem] {
    guard let vaultURL else { return [] }
    let patterns = filePatterns
    return try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return [] }
      return try self.withVaultAccess(vaultURL) { url in
        let files: [URL]
        if let list {
          let fileURL = url.appending(path: list.id)
          files = [fileURL]
        } else {
          files = self.scanMarkdownFiles(in: url, patterns: patterns)
        }
        return files.flatMap { fileURL -> [TaskItem] in
          let relPath = self.relativePath(for: fileURL, relativeTo: url)
          let vaultName = url.lastPathComponent
          let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
          let taskList = TaskList(
            id: relPath,
            providerID: Self.providerID,
            name: fileURL.deletingPathExtension().lastPathComponent
          )
          return self.parser.parse(
            content: content,
            providerID: Self.providerID,
            fileRelativePath: relPath,
            vaultName: vaultName,
            list: taskList
          ).items
        }
      }
    }.value
  }

  /// Returns a live stream that emits updated task arrays whenever any file in the vault changes.
  ///
  /// Uses `FSEventStreamCreate` for recursive directory watching. Rapid bursts of events are
  /// coalesced by a 250 ms debounce before a full rescan is triggered.
  func observe() -> AsyncStream<[TaskItem]>? {
    guard let vaultURL else { return nil }
    let (stream, continuation) = AsyncStream<[TaskItem]>.makeStream()
    streamContinuation = continuation
    startWatching(vaultURL: vaultURL, continuation: continuation)
    return stream
  }

  // MARK: - ClosableTaskProvider

  /// Rewrites the task checkbox from `[ ]` to `[x]` in the vault file, supporting both
  /// unordered (`- [ ] `) and ordered (`1. [ ] `) list formats.
  ///
  /// The stored line number is tried first; a file-wide search is the fallback for stale refs.
  func complete(_ ref: TaskRef) async throws {
    try await rewrite(ref: ref, from: " ", to: "x")
  }

  /// Rewrites the task checkbox from `[x]` / `[X]` back to `[ ]` in the vault file.
  func reopen(_ ref: TaskRef) async throws {
    try await rewrite(ref: ref, from: "x", to: " ", fallbackFrom: "X")
  }

  /// Scans the vault for all completed (`- [x]`) tasks, sorted by `✅` completion date descending.
  ///
  /// Tasks with no `✅` date appear after all dated tasks, in file-scan order.
  func completedTasks() async throws -> [TaskItem] {
    guard let vaultURL else { return [] }
    let patterns = filePatterns
    let entries: [TaskItem] = try await Task.detached(
      priority: .userInitiated
    ) { [weak self] in
      guard let self else { return [] }
      return try self.withVaultAccess(vaultURL) { url in
        self.scanMarkdownFiles(in: url, patterns: patterns).flatMap { fileURL in
          let relPath = self.relativePath(for: fileURL, relativeTo: url)
          let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
          let taskList = TaskList(
            id: relPath,
            providerID: Self.providerID,
            name: fileURL.deletingPathExtension().lastPathComponent
          )
          return self.parser.parseCompleted(
            content: content,
            providerID: Self.providerID,
            fileRelativePath: relPath,
            vaultName: url.lastPathComponent,
            list: taskList
          ).entries
        }
      }
    }.value
    return entries.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
  }

  // MARK: - Vault bookmark management

  /// Stores a security-scoped bookmark for `url` and sets it as the current vault.
  func saveVaultBookmark(for url: URL) throws {
    let bookmark = try url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    defaults.set(bookmark, forKey: Self.bookmarkKey)
    vaultURL = url
  }

  /// Clears the stored vault bookmark and stops any active file-system watcher.
  func clearVault() {
    defaults.removeObject(forKey: Self.bookmarkKey)
    vaultURL = nil
    stopWatching()
  }

  /// Replaces the current file pattern list and persists it to `UserDefaults`.
  func setFilePatterns(_ patterns: [String]) {
    filePatterns = patterns.isEmpty ? Self.defaultPatterns : patterns
    defaults.set(filePatterns, forKey: Self.patternsKey)
  }

  // MARK: - Private helpers

  private nonisolated func restoreVaultBookmark() {
    guard let data = defaults.data(forKey: Self.bookmarkKey) else { return }
    var isStale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    else { return }
    // vaultURL assignment and stale-refresh must happen on MainActor
    Task { @MainActor [weak self] in
      guard let self else { return }
      if isStale { try? self.saveVaultBookmark(for: url) }
      self.vaultURL = url
    }
  }

  /// Wraps `perform` with security-scoped resource access for `url`.
  private nonisolated func withVaultAccess<T>(_ url: URL, perform: (URL) throws -> T) throws -> T {
    let didStart = url.startAccessingSecurityScopedResource()
    defer { if didStart { url.stopAccessingSecurityScopedResource() } }
    return try perform(url)
  }

  /// Expands date tokens in a file-pattern string using the ISO 8601 calendar.
  ///
  /// Supported tokens: `{year}` / `{YYYY}` → 4-digit year, `{month}` / `{MM}` → zero-padded month,
  /// `{week}` / `{ww}` → ISO week number, `{day}` / `{DD}` → zero-padded day of month.
  nonisolated func expandTokens(_ pattern: String, now: Date = Date()) -> String {
    let cal = Calendar(identifier: .iso8601)
    let year = cal.component(.year, from: now)
    let month = cal.component(.month, from: now)
    let week = cal.component(.weekOfYear, from: now)
    let day = cal.component(.day, from: now)
    let opts: String.CompareOptions = [.caseInsensitive]
    return
      pattern
      .replacingOccurrences(of: "{year}", with: String(format: "%04d", year), options: opts)
      .replacingOccurrences(of: "{YYYY}", with: String(format: "%04d", year), options: opts)
      .replacingOccurrences(of: "{month}", with: String(format: "%02d", month), options: opts)
      .replacingOccurrences(of: "{MM}", with: String(format: "%02d", month), options: opts)
      .replacingOccurrences(of: "{week}", with: String(format: "%02d", week), options: opts)
      .replacingOccurrences(of: "{ww}", with: String(format: "%02d", week), options: opts)
      .replacingOccurrences(of: "{day}", with: String(format: "%02d", day), options: opts)
      .replacingOccurrences(of: "{DD}", with: String(format: "%02d", day), options: opts)
  }

  /// Returns all `.md` files under `vaultURL` that match `patterns` (after token expansion),
  /// skipping hidden files and directories.
  private nonisolated func scanMarkdownFiles(in vaultURL: URL, patterns: [String]) -> [URL] {
    let now = Date()
    let expandedPatterns = patterns.map { expandTokens($0, now: now) }
    guard
      let enumerator = FileManager.default.enumerator(
        at: vaultURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else { return [] }

    return
      enumerator
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "md" }
      .filter { fileURL in
        let rel = relativePath(for: fileURL, relativeTo: vaultURL)
        return Self.matchesPattern(rel, patterns: expandedPatterns)
      }
  }

  /// Returns `true` if `relativePath` matches any element of `patterns`.
  private nonisolated static func matchesPattern(
    _ relativePath: String,
    patterns: [String]
  ) -> Bool {
    patterns.contains { pattern in
      // fnmatch doesn't support **: strip the **/ prefix and match against the full relative path
      let simplified = pattern.hasPrefix("**/") ? String(pattern.dropFirst(3)) : pattern
      let filename = (relativePath as NSString).lastPathComponent
      return fnmatch(simplified, relativePath, FNM_PATHNAME) == 0
        || fnmatch(simplified, filename, FNM_PATHNAME) == 0
        || fnmatch(pattern, relativePath, 0) == 0
    }
  }

  /// Returns the path of `fileURL` relative to `vaultURL`, using `fileURL.path` as fallback.
  private nonisolated func relativePath(for fileURL: URL, relativeTo vaultURL: URL) -> String {
    let vaultPath = vaultURL.standardized.path
    let filePath = fileURL.standardized.path
    guard filePath.hasPrefix(vaultPath + "/") else { return filePath }
    return String(filePath.dropFirst(vaultPath.count + 1))
  }

  // MARK: - In-place line rewriting

  private func rewrite(
    ref: TaskRef,
    from fromCheckbox: String,
    to toCheckbox: String,
    fallbackFrom: String? = nil
  ) async throws {
    guard let vaultURL else {
      throw ObsidianProviderError.vaultNotConfigured
    }
    let parts = ref.nativeID.split(separator: ":", maxSplits: 1)
    guard parts.count == 2, let lineNumber = Int(parts[1]) else {
      throw ObsidianProviderError.invalidNativeID(ref.nativeID)
    }
    let relPath = String(parts[0])
    let fileURL = vaultURL.appending(path: relPath)

    try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      try self.withVaultAccess(vaultURL) { _ in
        var lines = try String(contentsOf: fileURL, encoding: .utf8)
          .components(separatedBy: "\n")
        let index = lineNumber - 1

        // Try the stored line number first; fall back to a file-wide search for stale refs.
        let (targetIndex, rewritten): (Int, String) = try {
          if index < lines.count {
            if let rewrite = Self.rewriteLine(lines[index], from: fromCheckbox, to: toCheckbox) {
              return (index, rewrite)
            }
            if let alt = fallbackFrom {
              if let rewrite = Self.rewriteLine(lines[index], from: alt, to: toCheckbox) {
                return (index, rewrite)
              }
            }
          }
          for (idx, line) in lines.enumerated() {
            if let rewrite = Self.rewriteLine(line, from: fromCheckbox, to: toCheckbox) {
              return (idx, rewrite)
            }
          }
          throw ObsidianProviderError.taskNotFound(ref.nativeID)
        }()
        lines[targetIndex] = rewritten
        let updated = lines.joined(separator: "\n")
        try Data(updated.utf8).write(to: fileURL, options: [])
      }
    }.value
  }

  /// Swaps the checkbox in `line` from `fromCheckbox` to `toCheckbox`, handling both
  /// unordered (`- [checkbox] `) and ordered (`N. [checkbox] `) list formats.
  /// Returns the rewritten line, or `nil` if no matching checkbox was found.
  private nonisolated static func rewriteLine(
    _ line: String,
    from fromCheckbox: String,
    to toCheckbox: String
  ) -> String? {
    let unordered = "- [\(fromCheckbox)] "
    if line.hasPrefix(unordered) {
      return "- [\(toCheckbox)] " + line.dropFirst(unordered.count)
    }
    var idx = line.startIndex
    while idx < line.endIndex, line[idx].isNumber {
      idx = line.index(after: idx)
    }
    guard idx > line.startIndex else { return nil }
    let numPart = String(line[..<idx])
    let remainder = String(line[idx...])
    let orderedSuffix = ". [\(fromCheckbox)] "
    guard remainder.hasPrefix(orderedSuffix) else { return nil }
    return numPart + ". [\(toCheckbox)] " + remainder.dropFirst(orderedSuffix.count)
  }

  // MARK: - File-system watching (FSEventStream)

  private func startWatching(
    vaultURL: URL,
    continuation: AsyncStream<[TaskItem]>.Continuation
  ) {
    let paths = [vaultURL.path] as CFArray
    // Pass an unretained pointer to self; safe because the stream is always stopped before
    // the provider is released (ObsidianProvider is a long-lived app singleton).
    var ctx = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(self).toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil
    )
    let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
      guard let info else { return }
      let provider = Unmanaged<ObsidianProvider>.fromOpaque(info).takeUnretainedValue()
      Task { @MainActor in provider.handleFSEvent() }
    }
    guard
      let stream = FSEventStreamCreate(
        kCFAllocatorDefault,
        callback,
        &ctx,
        paths,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        0.0,
        UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
      )
    else { return }
    FSEventStreamSetDispatchQueue(stream, .global(qos: .utility))
    FSEventStreamStart(stream)
    fsEventStream = stream
  }

  /// Called on `@MainActor` each time the FSEventStream fires; starts (or restarts) the debounce timer.
  private func handleFSEvent() {
    scheduleDebounce()
  }

  /// Cancels any pending rescan and schedules a new one 250 ms from now.
  private func scheduleDebounce() {
    debouncer.schedule { [weak self] in
      guard let self else { return }
      let updated = (try? await self.tasks(in: nil)) ?? []
      self.streamContinuation?.yield(updated)
    }
  }

  private func stopWatching() {
    debouncer.cancel()
    if let stream = fsEventStream {
      FSEventStreamStop(stream)
      FSEventStreamRelease(stream)
      fsEventStream = nil
    }
    streamContinuation?.finish()
    streamContinuation = nil
  }
}

// MARK: - Errors

/// Errors thrown by ``ObsidianProvider`` operations.
enum ObsidianProviderError: LocalizedError {
  /// The vault directory has not been configured by the user.
  case vaultNotConfigured
  /// The `TaskRef.nativeID` does not follow the expected `path:lineNumber` format.
  case invalidNativeID(String)
  /// No matching task line was found in the vault file.
  case taskNotFound(String)

  var errorDescription: String? {
    switch self {
    case .vaultNotConfigured:
      return "No Obsidian vault has been selected."
    case .invalidNativeID(let id):
      return "Invalid task reference: \"\(id)\"."
    case .taskNotFound(let id):
      return "Could not locate task \"\(id)\" in the vault."
    }
  }
}
