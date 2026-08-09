//
//  ObsidianProviderTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

// MARK: - Helpers

@MainActor
private func makeVault() throws -> URL {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

@MainActor
private func write(_ content: String, at relativePath: String, in vault: URL) throws {
  let dest = vault.appending(path: relativePath)
  let parent = dest.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
  try Data(content.utf8).write(to: dest, options: [])
}

@MainActor
private func makeProvider(vaultURL: URL?) -> ObsidianProvider {
  ObsidianProvider(
    store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
    vaultURL: vaultURL
  )
}

private enum ObserveTimeoutError: Error {
  case timedOut
  case finished
}

private func nextObservedTasks(
  from stream: AsyncStream<[TaskItem]>, timeout: Duration = .seconds(5)
) async throws -> [TaskItem] {
  try await withThrowingTaskGroup(of: [TaskItem]?.self) { group in
    group.addTask {
      var iterator = stream.makeAsyncIterator()
      return await iterator.next()
    }
    group.addTask {
      try await Task.sleep(for: timeout)
      throw ObserveTimeoutError.timedOut
    }
    guard let result = try await group.next() else { throw ObserveTimeoutError.timedOut }
    group.cancelAll()
    guard let tasks = result else { throw ObserveTimeoutError.finished }
    return tasks
  }
}

// MARK: - observe()

@Suite("ObsidianProvider — observe")
@MainActor
struct ObsidianProviderObserveTests {

  @Test func observeReturnsNilWhenVaultNotConfigured() {
    let provider = makeProvider(vaultURL: nil)
    #expect(provider.observe() == nil)
  }

  @Test func observeMulticastsUpdatesToConcurrentSubscribers() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Task 1", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)

    guard let firstStream = provider.observe(), let secondStream = provider.observe() else {
      Issue.record("observe() returned nil")
      return
    }

    try await Task.sleep(for: .milliseconds(100))
    try write("- [ ] Task 1\n- [ ] Task 2", at: "tasks.md", in: vault)

    let first = try await nextObservedTasks(from: firstStream)
    let second = try await nextObservedTasks(from: secondStream)
    #expect(first.map(\.title).sorted() == ["Task 1", "Task 2"])
    #expect(second.map(\.title).sorted() == ["Task 1", "Task 2"])
  }

  @Test func clearVaultFinishesExistingObservation() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Task 1", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let stream = try #require(provider.observe())

    provider.clearVault()

    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() == nil)
    #expect(!provider.isConfigured)
  }
}

// MARK: - completedTasks()

@Suite("ObsidianProvider — completedTasks")
@MainActor
struct ObsidianProviderCompletedTasksTests {

  @Test func vaultNotConfigured_returnsEmpty() async throws {
    let provider = makeProvider(vaultURL: nil)
    #expect(try await provider.completedTasks().isEmpty)
  }

  @Test func emptyVault_returnsEmpty() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let provider = makeProvider(vaultURL: vault)
    #expect(try await provider.completedTasks().isEmpty)
  }

  @Test func returnsCompletedTasksFromVault() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [x] Done ✅ 2025-12-01\n- [ ] Pending", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let tasks = try await provider.completedTasks()
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Done")
  }

  @Test func completedTasksItemsCarryCompletedAt() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [x] Done ✅ 2026-05-10\n- [ ] Pending", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let tasks = try await provider.completedTasks()
    #expect(tasks.count == 1)
    let stamp = try #require(tasks[0].completedAt)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let comps = cal.dateComponents([.year, .month, .day], from: stamp)
    #expect(comps.year == 2026)
    #expect(comps.month == 5)
    #expect(comps.day == 10)
  }

  @Test func excludesIncompleteTasks() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Pending\n- [ ] Also pending", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    #expect(try await provider.completedTasks().isEmpty)
  }

  @Test func scansSubdirectories() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [x] Nested done ✅ 2025-12-01", at: "Projects/work.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let tasks = try await provider.completedTasks()
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Nested done")
  }

  @Test func sortedByCompletionDateDescending() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      - [x] Older ✅ 2025-01-01
      - [x] Newer ✅ 2025-12-31
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let tasks = try await provider.completedTasks()
    #expect(tasks.count == 2)
    #expect(tasks[0].title == "Newer")
    #expect(tasks[1].title == "Older")
  }

  @Test func undatedTasksAppearAfterDatedOnes() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      - [x] No date
      - [x] Has date ✅ 2025-06-01
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let tasks = try await provider.completedTasks()
    #expect(tasks.count == 2)
    #expect(tasks[0].title == "Has date")
    #expect(tasks[1].title == "No date")
  }
}

// MARK: - complete() / reopen()

@Suite("ObsidianProvider — completion rewriting")
@MainActor
struct ObsidianProviderCompletionRewritingTests {

  @Test func completeUsesContentFingerprintAfterLineShift() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      - [ ] Delete me
      - [ ] Keep me
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let task = try #require((try await provider.tasks(in: nil)).first { $0.title == "Keep me" })

    try write("- [ ] Keep me", at: "tasks.md", in: vault)
    try await provider.complete(task.id)

    let updated = try String(contentsOf: vault.appending(path: "tasks.md"), encoding: .utf8)
    #expect(updated == "- [x] Keep me")
  }

  @Test func reopenUsesContentFingerprintAfterLineShift() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      - [x] Done first
      - [x] Keep done
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let task = try #require(
      (try await provider.completedTasks()).first { $0.title == "Keep done" })

    try write("- [x] Keep done", at: "tasks.md", in: vault)
    try await provider.reopen(task.id)

    let updated = try String(contentsOf: vault.appending(path: "tasks.md"), encoding: .utf8)
    #expect(updated == "- [ ] Keep done")
  }

  @Test func completeUsesLineHintForDuplicateContent() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      - [ ] Same task
      - [ ] Same task
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let task = try #require((try await provider.tasks(in: nil)).first)
    try await provider.complete(task.id)

    let updated = try String(contentsOf: vault.appending(path: "tasks.md"), encoding: .utf8)
    #expect(updated == "- [x] Same task\n- [ ] Same task")
  }

  @Test func completeThrowsWhenFingerprintHasNoLineHintAndIsAmbiguous() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write(
      """
      - [ ] Same task
      - [ ] Same task
      """, at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let task = try #require((try await provider.tasks(in: nil)).first)
    let fingerprintOnlyID = task.id.nativeID.components(separatedBy: "#line=")[0]
    let ref = TaskRef(providerID: task.id.providerID, nativeID: fingerprintOnlyID)

    await #expect(throws: ObsidianProviderError.self) {
      try await provider.complete(ref)
    }
  }

  @Test func legacyPathLineReferenceMatchesCurrentFingerprintTask() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    try write("- [ ] Legacy task", at: "tasks.md", in: vault)
    let provider = makeProvider(vaultURL: vault)
    let task = try #require((try await provider.tasks(in: nil)).first)
    let legacy = TaskRef(providerID: "obsidian", nativeID: "tasks.md:1")
    #expect(provider.matches(legacy, to: task))
  }
}

// MARK: - Token expansion

@Suite("ObsidianProvider — token expansion")
@MainActor
struct ObsidianProviderTokenExpansionTests {

  private func makeProvider() -> ObsidianProvider {
    ObsidianProvider(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!), vaultURL: nil)
  }

  private func date(year: Int, month: Int, day: Int) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    return Calendar(identifier: .iso8601).date(from: comps)!
  }

  @Test func noTokensPassthrough() {
    let provider = makeProvider()
    #expect(provider.expandTokens("**/Weekly/*.md") == "**/Weekly/*.md")
  }

  @Test func yearToken() {
    let provider = makeProvider()
    let now = date(year: 2026, month: 5, day: 28)
    #expect(provider.expandTokens("{year}", now: now) == "2026")
    #expect(provider.expandTokens("{YYYY}", now: now) == "2026")
  }

  @Test func supportedDateTokensAreValid() {
    #expect(
      ObsidianPatternTokens.invalidDateTokens(
        in: "{year}, {YYYY}, {Year}, {month}, {MM}, {week}, {ww}, {day}, {DD}"
      ).isEmpty)
  }

  @Test func invalidDateTokensAreReported() {
    #expect(
      ObsidianPatternTokens.invalidDateTokens(in: "Daily/{yy}/{mmm}/{weekday}/{D}.md")
        == ["{yy}", "{mmm}", "{weekday}", "{D}"])
  }

  @Test func dateTokensWithInteriorSpacesAreReported() {
    #expect(
      ObsidianPatternTokens.invalidDateTokens(in: "Daily/{ year }/{ yy }/{week }.md")
        == ["{ year }", "{ yy }", "{week }"])
  }

  @Test func malformedDateTokensAreReported() {
    #expect(ObsidianPatternTokens.invalidDateTokens(in: "Daily/{w ! w}.md") == ["{w ! w}"])
  }

  @Test func duplicateInvalidDateTokensAreReportedOnce() {
    #expect(ObsidianPatternTokens.invalidDateTokens(in: "{yy}/{yy}.md") == ["{yy}"])
  }

  @Test func monthToken() {
    let provider = makeProvider()
    let now = date(year: 2026, month: 3, day: 15)
    #expect(provider.expandTokens("{month}", now: now) == "03")
    #expect(provider.expandTokens("{MM}", now: now) == "03")
  }

  @Test func weekToken() {
    let provider = makeProvider()
    // 2026-01-05 is ISO week 2
    let now = date(year: 2026, month: 1, day: 5)
    #expect(provider.expandTokens("{week}", now: now) == "02")
    #expect(provider.expandTokens("{ww}", now: now) == "02")
  }

  @Test func dayToken() {
    let provider = makeProvider()
    let now = date(year: 2026, month: 5, day: 7)
    #expect(provider.expandTokens("{day}", now: now) == "07")
    #expect(provider.expandTokens("{DD}", now: now) == "07")
  }

  @Test func compositePeriodicPattern() {
    let provider = makeProvider()
    // 2026-05-28 = ISO week 22
    let now = date(year: 2026, month: 5, day: 28)
    let result = provider.expandTokens("**/Weekly/{YYYY}-W{ww}.md", now: now)
    #expect(result == "**/Weekly/2026-W22.md")
  }

  @Test func tokenExpansionAppliedDuringVaultScan() async throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let cal = Calendar(identifier: .iso8601)
    let now = Date()
    let year = cal.component(.year, from: now)
    let week = cal.component(.weekOfYear, from: now)
    let filename = String(format: "%04d-W%02d.md", year, week)
    try write("- [ ] Weekly task", at: "Weekly/\(filename)", in: vault)
    let provider = ObsidianProvider(
      store: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
      vaultURL: vault,
      filePatterns: ["**/Weekly/{YYYY}-W{ww}.md"]
    )
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Weekly task")
  }
}

// MARK: - Vault bookmark restore

@Suite("ObsidianProvider — vault bookmark restore")
@MainActor
struct ObsidianProviderBookmarkRestoreTests {

  /// A provider constructed over a store that already holds a vault bookmark must expose
  /// `vaultURL` synchronously from `init` — before any list load — so the sidebar's first
  /// `lists()` call after a cold launch sees a configured vault. A deferred assignment races
  /// that load and leaves the vault appearing unconfigured.
  @Test func restoresVaultSynchronouslyFromPersistedBookmark() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }

    let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    try ObsidianProvider(store: settings).saveVaultBookmark(for: vault)

    // A fresh provider over the same store resolves the bookmark during init — no await.
    let restored = ObsidianProvider(store: settings)
    #expect(restored.isConfigured)
    #expect(restored.vaultURL?.standardizedFileURL == vault.standardizedFileURL)
  }

  /// An empty store leaves the provider unconfigured rather than resolving a phantom vault.
  @Test func staysUnconfiguredWithoutPersistedBookmark() {
    let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let provider = ObsidianProvider(store: settings)
    #expect(!provider.isConfigured)
    #expect(provider.vaultURL == nil)
  }
}

// MARK: - ConfigurableTaskProvider

@Suite("ObsidianProvider — ConfigurableTaskProvider")
@MainActor
struct ObsidianProviderConfigurableTests {

  /// A provider with no vault still needs setup, so enabling it should present the sheet.
  @Test func needsConfigurationWhenNoVaultSelected() {
    let provider = makeProvider(vaultURL: nil)
    #expect(provider.needsConfiguration)
  }

  /// A provider with a vault already selected does not need to reopen the setup sheet.
  @Test func doesNotNeedConfigurationWhenVaultSelected() throws {
    let vault = try makeVault()
    defer { try? FileManager.default.removeItem(at: vault) }
    let provider = makeProvider(vaultURL: vault)
    #expect(!provider.needsConfiguration)
  }
}
