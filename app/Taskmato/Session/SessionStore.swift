//
//  SessionStore.swift
//  Taskmato
//

import Foundation
import Observation

/// Persists and provides access to the log of completed Pomodoro sessions.
///
/// Sessions are stored as a JSON array at the path passed to `init(fileURL:)`.
/// The production path is `~/Library/Application Support/Taskmato/sessions.json`.
@Observable
final class SessionStore {

  /// All recorded sessions, ordered oldest-first.
  private(set) var sessions: [Session] = []

  private let fileURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// Creates a store using the default production file path.
  convenience init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.init(fileURL: dir.appendingPathComponent("sessions.json"))
  }

  /// Creates a store using a specific file URL. Pass a temporary path in tests.
  init(fileURL: URL) {
    self.fileURL = fileURL
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
    load()
  }

  /// Appends a session record to the log and writes it to disk.
  func append(_ session: Session) {
    sessions.append(session)
    save()
  }

  /// Returns the phase that should begin when the user presses Start from idle.
  ///
  /// Returns the appropriate break type after a completed focus session, or `.focus` otherwise.
  /// - Parameter longBreakAfter: Number of completed focus sessions before a long break.
  func nextPhaseToStart(longBreakAfter: Int) -> SessionPhase {
    guard let last = sessions.last, last.wasCompleted else { return .focus }
    switch last.phase {
    case .focus: return nextBreakPhase(longBreakAfter: longBreakAfter)
    case .shortBreak, .longBreak: return .focus
    }
  }

  /// Returns the appropriate break phase for the next session based on the history.
  ///
  /// Counts completed focus sessions since the last completed long break.
  /// Partial sessions and skipped phases are excluded from the count.
  /// - Parameter longBreakAfter: Number of completed focus sessions before a long break.
  func nextBreakPhase(longBreakAfter: Int) -> SessionPhase {
    let completedFocusSinceLastLongBreak =
      sessions
      .reversed()
      .prefix(while: { !($0.phase == .longBreak && $0.wasCompleted) })
      .filter({ $0.phase == .focus && $0.wasCompleted })
      .count
    guard completedFocusSinceLastLongBreak > 0,
      completedFocusSinceLastLongBreak % longBreakAfter == 0
    else {
      return .shortBreak
    }
    return .longBreak
  }

  /// Number of completed focus sessions that started today (calendar day, local time zone).
  func todayFocusCount() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return sessions.filter {
      $0.phase == .focus && $0.wasCompleted && calendar.startOfDay(for: $0.startedAt) == today
    }.count
  }

  /// Total elapsed minutes across all completed focus sessions that started today.
  func todayFocusMinutes() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let total = sessions.filter {
      $0.phase == .focus && $0.wasCompleted && calendar.startOfDay(for: $0.startedAt) == today
    }.reduce(0) { $0 + $1.duration }
    return Int(total / 60)
  }

  // MARK: - Private

  private func load() {
    guard let data = try? Data(contentsOf: fileURL) else { return }
    sessions = (try? decoder.decode([Session].self, from: data)) ?? []
  }

  private func save() {
    guard let data = try? encoder.encode(sessions) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
