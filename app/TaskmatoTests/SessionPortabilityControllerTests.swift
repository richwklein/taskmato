//
//  SessionPortabilityControllerTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
@Suite("Session portability controller")
struct SessionPortabilityControllerTests {

  @Test func localMutationAfterPreviewRequiresReconfirmationBeforeMerge() async throws {
    let repository = FakeSessionRepository()
    let store = SessionStore(repository: repository)
    let controller = SessionPortabilityController(store: store)
    let imported = makeSession(id: UUID(), start: Date(timeIntervalSince1970: 10), duration: 60)
    let url = try write(document: try SessionPortability.makeDocument(sessions: [imported]))
    defer { try? FileManager.default.removeItem(at: url) }

    controller.preflightImport(from: url)
    await controller.waitForOperation()
    guard case .awaitingConfirmation(let firstPlan) = controller.state else {
      Issue.record("Expected an import preview")
      return
    }

    let local = makeSession(id: UUID(), start: Date(timeIntervalSince1970: 20), duration: 30)
    store.append(local)
    controller.confirmImport()
    await controller.waitForOperation()

    guard case .awaitingConfirmation(let secondPlan) = controller.state else {
      Issue.record("Expected reconfirmation after the local revision changed")
      return
    }
    #expect(secondPlan.historyRevision > firstPlan.historyRevision)
    #expect(secondPlan.preview.result.inserted == 1)
    let durable = try await store.durableSnapshot()
    #expect(Set(durable.map(\.id)) == [local.id])
  }

  private func makeSession(id: UUID, start: Date, duration: TimeInterval) -> Session {
    Session(
      id: id, phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(duration),
      wasCompleted: true)
  }

  private func write(document: SessionHistoryDocumentV1) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("json")
    try SessionPortability.encode(document).write(to: url)
    return url
  }
}
