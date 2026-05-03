//
//  SessionStoreTests.swift
//  TaskmatoTests
//

import Testing
@testable import Taskmato
import Foundation

struct SessionStoreTests {

    /// Returns a store backed by a unique temporary file that won't affect production data.
    private func makeStore() -> SessionStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        return SessionStore(fileURL: url)
    }

    private func makeSession(phase: SessionPhase = .focus, wasCompleted: Bool = true) -> Session {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return Session(id: UUID(), phase: phase, startedAt: start, endedAt: start.addingTimeInterval(1500), wasCompleted: wasCompleted)
    }

    @Test func appendIncreasesCount() {
        let store = makeStore()
        store.append(makeSession())
        #expect(store.sessions.count == 1)
    }

    @Test func appendedSessionIsRetrievable() {
        let store = makeStore()
        let session = makeSession(phase: .shortBreak)
        store.append(session)
        #expect(store.sessions.first?.id == session.id)
        #expect(store.sessions.first?.phase == .shortBreak)
    }

    @Test func multipleSessionsAreOrderedOldestFirst() {
        let store = makeStore()
        let first = makeSession(phase: .focus)
        let second = makeSession(phase: .shortBreak)
        store.append(first)
        store.append(second)
        #expect(store.sessions.first?.id == first.id)
        #expect(store.sessions.last?.id == second.id)
    }

    @Test func sessionsRoundTripThroughDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")

        let session = makeSession(phase: .focus)

        let writer = SessionStore(fileURL: url)
        writer.append(session)

        let reader = SessionStore(fileURL: url)
        #expect(reader.sessions.count == 1)
        #expect(reader.sessions.first?.id == session.id)
        #expect(reader.sessions.first?.phase == .focus)
    }

    @Test func sessionDurationIsEndMinusStart() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let session = Session(id: UUID(), phase: .focus, startedAt: start, endedAt: start.addingTimeInterval(1500), wasCompleted: true)
        #expect(session.duration == 1500)
    }

    // MARK: - nextBreakPhase

    @Test func nextBreakPhaseIsShortBreakWithNoHistory() {
        let store = makeStore()
        #expect(store.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
    }

    @Test func nextBreakPhaseIsShortBreakAfterFirstFocus() {
        let store = makeStore()
        store.append(makeSession(phase: .focus))
        #expect(store.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
    }

    @Test func nextBreakPhaseIsLongBreakAfterNFocusSessions() {
        let store = makeStore()
        for _ in 0..<4 {
            store.append(makeSession(phase: .focus))
        }
        #expect(store.nextBreakPhase(longBreakAfter: 4) == .longBreak)
    }

    @Test func nextBreakPhaseResetsAfterCompletedLongBreak() {
        let store = makeStore()
        for _ in 0..<4 {
            store.append(makeSession(phase: .focus))
        }
        store.append(makeSession(phase: .longBreak, wasCompleted: true))
        store.append(makeSession(phase: .focus))
        #expect(store.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
    }

    @Test func nextBreakPhaseExcludesPartialFocusSessions() {
        let store = makeStore()
        for _ in 0..<3 {
            store.append(makeSession(phase: .focus, wasCompleted: true))
        }
        store.append(makeSession(phase: .focus, wasCompleted: false))
        #expect(store.nextBreakPhase(longBreakAfter: 4) == .shortBreak)
    }

    @Test func nextBreakPhaseDoesNotResetAfterIncompleteLongBreak() {
        let store = makeStore()
        for _ in 0..<4 {
            store.append(makeSession(phase: .focus))
        }
        store.append(makeSession(phase: .longBreak, wasCompleted: false))
        #expect(store.nextBreakPhase(longBreakAfter: 4) == .longBreak)
    }

    @Test func nextBreakPhaseRespectsCustomInterval() {
        let store = makeStore()
        for _ in 0..<2 {
            store.append(makeSession(phase: .focus))
        }
        #expect(store.nextBreakPhase(longBreakAfter: 2) == .longBreak)
    }

    // MARK: - nextPhaseToStart

    @Test func nextPhaseToStartWithNoHistoryReturnsFocus() {
        let store = makeStore()
        #expect(store.nextPhaseToStart(longBreakAfter: 4) == .focus)
    }

    @Test func nextPhaseToStartAfterCompletedFocusReturnsShortBreak() {
        let store = makeStore()
        store.append(makeSession(phase: .focus, wasCompleted: true))
        #expect(store.nextPhaseToStart(longBreakAfter: 4) == .shortBreak)
    }

    @Test func nextPhaseToStartAfterCompletedFocusReturnsLongBreak() {
        let store = makeStore()
        for _ in 0..<4 {
            store.append(makeSession(phase: .focus, wasCompleted: true))
        }
        #expect(store.nextPhaseToStart(longBreakAfter: 4) == .longBreak)
    }

    @Test func nextPhaseToStartAfterCompletedShortBreakReturnsFocus() {
        let store = makeStore()
        store.append(makeSession(phase: .shortBreak, wasCompleted: true))
        #expect(store.nextPhaseToStart(longBreakAfter: 4) == .focus)
    }

    @Test func nextPhaseToStartAfterCompletedLongBreakReturnsFocus() {
        let store = makeStore()
        store.append(makeSession(phase: .longBreak, wasCompleted: true))
        #expect(store.nextPhaseToStart(longBreakAfter: 4) == .focus)
    }

    @Test func nextPhaseToStartAfterPartialFocusReturnsFocus() {
        let store = makeStore()
        store.append(makeSession(phase: .focus, wasCompleted: false))
        #expect(store.nextPhaseToStart(longBreakAfter: 4) == .focus)
    }
}
