//
//  ObsidianProvider.swift
//  Taskmato
//

import AppKit
import CoreServices
import Foundation
import Observation

/// A task provider that reads and writes tasks in all matching markdown files in an Obsidian vault.
///
/// Vault directory access uses a security-scoped bookmark persisted in ``UserDefaults``.
/// `complete(_:)` rewrites the task line from `- [ ]` to `- [x]` in place; `reopen(_:)` reverses
/// the operation; `completedTasks()` scans the vault for `- [x]` lines and returns them sorted by
/// their `✅` completion date. The provider conforms to ``WritableTaskProvider`` so tasks can also
/// be created, edited, and deleted — but not ``WritableListProvider``: vault files already have a
/// mature native lifecycle (Obsidian.app, Finder, sync tools), so file create/rename/delete stays
/// out of scope. See ADR-0011.
///
/// - Note: `observe()` watches the vault recursively using `FSEventStreamCreate`. Rapid
///   change notifications are coalesced by a 250 ms debounce before a rescan is triggered.
@Observable
@MainActor
final class ObsidianProvider: WritableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  nonisolated static let providerID: ProviderID = "obsidian"

  let id: ProviderID = ObsidianProvider.providerID
  let displayName: String = "Obsidian"
  let icon: String = "book.closed"
  let tint: ProviderTint = .purple
  let entitlement: ProviderEntitlement = .free

  /// The `ContentFormat` new and edited tasks use — Obsidian task lines are markdown.
  let contentFormat: ContentFormat = .markdown

  /// Obsidian's `📅 YYYY-MM-DD` task-line format has no time-of-day convention — writes are
  /// always date-only, matching the obsidian-tasks plugin other tools in a vault expect.
  let supportsDueTime: Bool = false

  /// The user-selected vault directory, resolved from the stored security-scoped bookmark.
  private(set) var vaultURL: URL?

  /// Glob patterns (relative to vault root) used to select which markdown files are scanned.
  /// Supported date tokens are documented on ``expandTokens(_:now:)``.
  private(set) var filePatterns: [String]

  /// User-selected default file (vault-relative path), or `nil` if none has been chosen.
  ///
  /// Unlike Reminders, Obsidian has no system-level default to fall back to.
  var defaultListOverride: String? {
    didSet { store[SettingsStore.Keys.obsidianDefaultListID] = defaultListOverride }
  }

  /// The vault-relative path of the file new tasks target by default, or `nil` if none is set.
  var defaultListID: String? { defaultListOverride }

  /// Human-readable vault name derived from the last path component of `vaultURL`.
  var vaultName: String { vaultURL?.lastPathComponent ?? "" }

  /// Whether the user has selected a vault directory.
  var isConfigured: Bool { vaultURL != nil }

  private let store: SettingsStore
  private let parser = ObsidianTaskParser()
  private let updates = MulticastAsyncStream<[TaskItem]>()
  private var fsEventStream: FSEventStreamRef?
  private let debouncer = Debouncer()

  private static let defaultPatterns = ["**/*.md"]

  init(store: SettingsStore = SettingsStore()) {
    self.store = store
    self.filePatterns = store[SettingsStore.Keys.obsidianFilePatterns]
    self.defaultListOverride = store[SettingsStore.Keys.obsidianDefaultListID]
    restoreVaultBookmark()
    updates.onEmpty = { [weak self] in self?.stopWatching() }
  }

  /// Creates a pre-configured provider for unit tests, bypassing the settings-store bookmark lookup.
  init(
    store: SettingsStore,
    vaultURL: URL?,
    filePatterns: [String] = ObsidianProvider.defaultPatterns,
    defaultListID: String? = nil
  ) {
    self.store = store
    self.filePatterns = filePatterns
    self.vaultURL = vaultURL
    self.defaultListOverride = defaultListID
    updates.onEmpty = { [weak self] in self?.stopWatching() }
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
    let stream = updates.subscribe()
    if fsEventStream == nil {
      startWatching(vaultURL: vaultURL)
    }
    return stream
  }

  /// Matches current fingerprint IDs and legacy path/line IDs without making line the identity.
  func matches(_ ref: TaskRef, to task: TaskItem) -> Bool {
    guard ref.providerID == Self.providerID,
      let persisted = ObsidianTaskIdentity.parseNativeID(ref.nativeID),
      let current = ObsidianTaskIdentity.parseNativeID(task.id.nativeID),
      persisted.fileRelativePath == current.fileRelativePath
    else { return false }
    if let fingerprint = persisted.fingerprint {
      return fingerprint == current.fingerprint
    }
    return persisted.lineNumber == current.lineNumber
  }

  /// Resolves duplicate content fingerprints with the persisted line as a non-authoritative hint.
  func resolve(_ ref: TaskRef, among tasks: [TaskItem]) -> TaskItem? {
    let candidates = tasks.filter { matches(ref, to: $0) }
    guard candidates.count > 1,
      let lineNumber = ObsidianTaskIdentity.parseNativeID(ref.nativeID)?.lineNumber
    else { return candidates.first }
    let ranked = candidates.sorted {
      distance(from: lineNumber, to: $0) < distance(from: lineNumber, to: $1)
    }
    guard distance(from: lineNumber, to: ranked[0]) < distance(from: lineNumber, to: ranked[1])
    else {
      return nil
    }
    return ranked[0]
  }

  private func distance(from lineNumber: Int, to task: TaskItem) -> Int {
    guard let currentLine = ObsidianTaskIdentity.parseNativeID(task.id.nativeID)?.lineNumber else {
      return Int.max
    }
    return abs(currentLine - lineNumber)
  }

  // MARK: - ClosableTaskProvider

  /// Rewrites the task checkbox from `[ ]` to `[x]` in the vault file, supporting both
  /// unordered (`- [ ] `) and ordered (`1. [ ] `) list formats.
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
    store.setData(bookmark, forKey: SettingsStore.Keys.obsidianVaultBookmark)
    vaultURL = url
  }

  /// Clears the stored vault bookmark and stops any active file-system watcher.
  func clearVault() {
    store.setData(nil, forKey: SettingsStore.Keys.obsidianVaultBookmark)
    vaultURL = nil
    stopWatching()
  }

  /// Replaces the current file pattern list and persists it through the settings store.
  func setFilePatterns(_ patterns: [String]) {
    filePatterns = patterns.isEmpty ? Self.defaultPatterns : patterns
    store[SettingsStore.Keys.obsidianFilePatterns] = filePatterns
  }

  // MARK: - Private helpers

  /// Resolves the persisted security-scoped bookmark into ``vaultURL``, refreshing the stored
  /// bookmark when the system reports it stale.
  ///
  /// Runs synchronously from `init` so ``vaultURL`` is set before the sidebar's first `lists()`
  /// load. A deferred assignment races that load and leaves the vault appearing unconfigured after
  /// a cold launch, even though the bookmark persisted correctly.
  private func restoreVaultBookmark() {
    guard let data = store.data(forKey: SettingsStore.Keys.obsidianVaultBookmark) else { return }
    var isStale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    else { return }
    vaultURL = url
    if isStale { try? saveVaultBookmark(for: url) }
  }

  /// Wraps `perform` with security-scoped resource access for `url`.
  nonisolated func withVaultAccess<T>(_ url: URL, perform: (URL) throws -> T) throws -> T {
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
    let vaultPath = vaultURL.standardizedFileURL.resolvingSymlinksInPath().path
    let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
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
    guard let identity = ObsidianTaskIdentity.parseNativeID(ref.nativeID) else {
      throw ObsidianProviderError.invalidNativeID(ref.nativeID)
    }
    let fileURL = vaultURL.appending(path: identity.fileRelativePath)

    try await Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      try self.withVaultAccess(vaultURL) { _ in
        var lines = try String(contentsOf: fileURL, encoding: .utf8)
          .components(separatedBy: "\n")

        let matches = Self.matchingLines(
          lines, identity: identity, from: fromCheckbox, replacement: toCheckbox,
          fallbackFrom: fallbackFrom)
        let target = try Self.selectTarget(matches, lineNumber: identity.lineNumber, ref: ref)
        let (targetIndex, rewritten) = target
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

  private nonisolated static func rewrittenLine(
    _ line: String, from: String, replacement: String, fallbackFrom: String?
  ) -> String? {
    rewriteLine(line, from: from, to: replacement)
      ?? fallbackFrom.flatMap { rewriteLine(line, from: $0, to: replacement) }
  }

  private nonisolated static func matchingLines(
    _ lines: [String], identity: ObsidianTaskIdentity.Components,
    from: String, replacement: String, fallbackFrom: String?
  ) -> [(Int, String)] {
    lines.enumerated().compactMap { index, line in
      if let fingerprint = identity.fingerprint {
        guard ObsidianTaskIdentity.fingerprint(for: line) == fingerprint else { return nil }
      } else {
        guard identity.lineNumber == index + 1 else { return nil }
      }
      guard
        let rewritten = rewrittenLine(
          line, from: from, replacement: replacement, fallbackFrom: fallbackFrom)
      else { return nil }
      return (index, rewritten)
    }
  }

  private nonisolated static func selectTarget(
    _ matches: [(Int, String)], lineNumber: Int?, ref: TaskRef
  ) throws -> (Int, String) {
    guard !matches.isEmpty else { throw ObsidianProviderError.taskNotFound(ref.nativeID) }
    guard matches.count > 1 else { return matches[0] }
    guard let lineNumber else { throw ObsidianProviderError.ambiguousTaskRef(ref.nativeID) }
    let ranked = matches.sorted { abs($0.0 + 1 - lineNumber) < abs($1.0 + 1 - lineNumber) }
    let bestDistance = abs(ranked[0].0 + 1 - lineNumber)
    guard ranked.dropFirst().first.map({ abs($0.0 + 1 - lineNumber) > bestDistance }) ?? true
    else { throw ObsidianProviderError.ambiguousTaskRef(ref.nativeID) }
    return ranked[0]
  }
}

/// Retained by the FSEventStream context while callbacks may still arrive; the weak provider
/// reference prevents the stream bridge from extending the provider's lifetime.
private final class ObsidianFSEventContext: @unchecked Sendable {
  weak var provider: ObsidianProvider?

  @MainActor
  init(provider: ObsidianProvider) {
    self.provider = provider
  }
}

/// C callback table for the FSEventStream context, including its explicit Unmanaged ownership
/// bridge and hop back to the provider's main actor.
private nonisolated enum ObsidianFSEventCallbacks {
  static let retain: CFAllocatorRetainCallBack = { info in
    guard let info else { return nil }
    return UnsafeRawPointer(Unmanaged<ObsidianFSEventContext>.fromOpaque(info).retain().toOpaque())
  }

  static let release: CFAllocatorReleaseCallBack = { info in
    guard let info else { return }
    Unmanaged<ObsidianFSEventContext>.fromOpaque(info).release()
  }

  static let handleEvent: FSEventStreamCallback = { _, info, _, _, _, _ in
    guard let info else { return }
    let context = Unmanaged<ObsidianFSEventContext>.fromOpaque(info).takeUnretainedValue()
    Task { @MainActor [context] in
      context.provider?.handleFSEvent()
    }
  }
}

extension ObsidianProvider {

  // MARK: - File-system watching (FSEventStream)

  private func startWatching(vaultURL: URL) {
    let paths = [vaultURL.path] as CFArray
    let context = ObsidianFSEventContext(provider: self)
    var ctx = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(context).toOpaque(),
      retain: ObsidianFSEventCallbacks.retain,
      release: ObsidianFSEventCallbacks.release,
      copyDescription: nil
    )
    guard
      let stream = FSEventStreamCreate(
        kCFAllocatorDefault,
        ObsidianFSEventCallbacks.handleEvent,
        &ctx,
        paths,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        0.0,
        UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
      )
    else {
      return
    }
    FSEventStreamSetDispatchQueue(stream, .global(qos: .utility))
    FSEventStreamStart(stream)
    fsEventStream = stream
  }

  /// Called on `@MainActor` each time the FSEventStream fires; starts (or restarts) the debounce timer.
  fileprivate func handleFSEvent() {
    scheduleDebounce()
  }

  /// Cancels any pending rescan and schedules a new one 250 ms from now.
  private func scheduleDebounce() {
    debouncer.schedule { [weak self] in
      guard let self else { return }
      let updated = (try? await self.tasks(in: nil)) ?? []
      self.updates.yield(updated)
    }
  }

  private func stopWatching() {
    debouncer.cancel()
    if let stream = fsEventStream {
      fsEventStream = nil
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
    }
    updates.finish()
  }
}
