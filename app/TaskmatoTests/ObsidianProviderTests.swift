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
    defaults: UserDefaults(suiteName: UUID().uuidString)!,
    vaultURL: vaultURL
  )
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

// MARK: - Token expansion

@Suite("ObsidianProvider — token expansion")
@MainActor
struct ObsidianProviderTokenExpansionTests {

  private func makeProvider() -> ObsidianProvider {
    ObsidianProvider(defaults: UserDefaults(suiteName: UUID().uuidString)!, vaultURL: nil)
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
      defaults: UserDefaults(suiteName: UUID().uuidString)!,
      vaultURL: vault,
      filePatterns: ["**/Weekly/{YYYY}-W{ww}.md"]
    )
    let tasks = try await provider.tasks(in: nil)
    #expect(tasks.count == 1)
    #expect(tasks[0].title == "Weekly task")
  }
}
