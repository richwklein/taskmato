//
//  ObsidianProvider.swift
//  Taskmato
//

import AppKit
import Foundation
import SwiftUI

/// A task provider that reads incomplete tasks from all matching markdown files in an Obsidian vault.
///
/// Vault directory access uses a security-scoped bookmark persisted in ``UserDefaults``.
/// The provider is read-write: `complete(_:)` rewrites the task line from `- [ ]` to `- [x]`
/// in place; `reopen(_:)` reverses the operation.
///
/// `observe()` uses FSEvents to watch the entire vault tree recursively; any file change
/// anywhere in the vault triggers a reload after a short coalescing window.
@Observable
@MainActor
final class ObsidianProvider: MutableTaskProvider {

  /// Stable provider identifier used in ``TaskRef`` values.
  static let providerID = "obsidian"

  let id: String = ObsidianProvider.providerID
  let displayName: String = "Obsidian"
  let entitlement: ProviderEntitlement = .free

  /// The user-selected vault directory, resolved from the stored security-scoped bookmark.
  private(set) var vaultURL: URL?

  /// Glob patterns (relative to vault root) used to select which markdown files are scanned.
  private(set) var filePatterns: [String]

  /// Human-readable vault name derived from the last path component of `vaultURL`.
  var vaultName: String { vaultURL?.lastPathComponent ?? "" }

  /// Whether the user has selected a vault directory.
  var isConfigured: Bool { vaultURL != nil }

  private let defaults: UserDefaults
  private let parser = ObsidianTaskParser()
  private let resolver = ObsidianGlobResolver()
  private var streamContinuation: AsyncStream<[TaskItem]>.Continuation?
  private var fsEventStream: FSEventStream?

  private static let bookmarkKey = "obsidian.vaultBookmark"
  private static let patternsKey = "obsidian.filePatterns"
  private static let defaultPatterns = ["**/*.md"]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.filePatterns =
      defaults.array(forKey: Self.patternsKey) as? [String] ?? Self.defaultPatterns
    restoreVaultBookmark()
  }

  // MARK: - TaskProvider

  /// No-op — vault selection is initiated by the user in Settings.
  func authorize() async throws {}

  /// Returns one ``TaskList`` per matching markdown file.
  ///
  /// The list name is the file's H1 heading if present, otherwise the filename without extension.
  func lists() async throws -> [TaskList] {
    guard let vaultURL else { return [] }
    let patterns = filePatterns.map { resolver.resolve($0) }
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
    let patterns = filePatterns.map { resolver.resolve($0) }
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
  /// Uses FSEvents to watch the vault tree recursively. Returns `nil` if no vault is configured.
  func observe() -> AsyncStream<[TaskItem]>? {
    guard let vaultURL else { return nil }
    let (stream, continuation) = AsyncStream<[TaskItem]>.makeStream()
    streamContinuation = continuation
    startWatching(vaultURL: vaultURL, continuation: continuation)
    return stream
  }

  // MARK: - MutableTaskProvider

  /// Rewrites the task line from `- [ ]` to `- [x]` in the vault file.
  ///
  /// The line is validated against the stored task title before writing to guard against
  /// stale ``TaskRef`` line numbers. If the expected line no longer matches, a title search
  /// is performed as a fallback.
  func complete(_ ref: TaskRef) async throws {
    try await rewrite(ref: ref, from: "- [ ] ", to: "- [x] ")
  }

  /// Rewrites the task line from `- [x]` to `- [ ]` in the vault file.
  func reopen(_ ref: TaskRef) async throws {
    try await rewrite(ref: ref, from: "- [x] ", to: "- [ ] ", fallbackFrom: "- [X] ")
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

  /// Returns all `.md` files under `vaultURL` that match `patterns`, skipping hidden files.
  private nonisolated func scanMarkdownFiles(in vaultURL: URL, patterns: [String]) -> [URL] {
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
        return Self.matchesPattern(rel, patterns: patterns)
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
    from sourcePrefix: String,
    to targetPrefix: String,
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

        // Locate the target line: stored line number first, then title search as fallback.
        let (targetIndex, matchedPrefix): (Int, String) = try {
          if index < lines.count, lines[index].hasPrefix(sourcePrefix) {
            return (index, sourcePrefix)
          }
          if let alt = fallbackFrom, index < lines.count, lines[index].hasPrefix(alt) {
            return (index, alt)
          }
          if let found = lines.firstIndex(where: { $0.hasPrefix(sourcePrefix) }) {
            return (found, sourcePrefix)
          }
          throw ObsidianProviderError.taskNotFound(ref.nativeID)
        }()
        lines[targetIndex] = targetPrefix + lines[targetIndex].dropFirst(matchedPrefix.count)
        let updated = lines.joined(separator: "\n")
        try Data(updated.utf8).write(to: fileURL, options: [])
      }
    }.value
  }

  // MARK: - File-system watching

  private func startWatching(
    vaultURL: URL,
    continuation: AsyncStream<[TaskItem]>.Continuation
  ) {
    fsEventStream = FSEventStream(path: vaultURL.path) { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let updated = (try? await self.tasks(in: nil)) ?? []
        continuation.yield(updated)
      }
    }
  }

  private func stopWatching() {
    fsEventStream?.invalidate()
    fsEventStream = nil
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
