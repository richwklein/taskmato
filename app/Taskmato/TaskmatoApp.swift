//
//  TaskmatoApp.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import SwiftUI

@main
struct TaskmatoApp: App {

    @State private var engine: SessionEngine
    @State private var settings: AppSettings
    @State private var store: SessionStore
    @State private var notifications: NotificationService
    @State private var sounds: SoundService

    init() {
        let engine = SessionEngine()
        let settings = AppSettings()
        let store = SessionStore()
        let notifications = NotificationService()
        let sounds = SoundService()

        engine.onPhaseEnded = { phase, startedAt, endedAt, wasCompleted in
            store.append(Session(
                id: UUID(),
                phase: phase,
                startedAt: startedAt,
                endedAt: endedAt,
                wasCompleted: wasCompleted
            ))
            if wasCompleted {
                if settings.soundEnabled         { sounds.play() }
                if settings.notificationsEnabled { notifications.send(phase: phase) }
                engine.focusDuration      = settings.focusDuration
                engine.shortBreakDuration = settings.shortBreakDuration
                engine.longBreakDuration  = settings.longBreakDuration
                let next: SessionPhase
                switch phase {
                case .focus: next = store.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
                case .shortBreak, .longBreak: next = .focus
                }
                if settings.autoStartNextPhase {
                    engine.start(phase: next)
                } else {
                    engine.enqueuePhase(next)
                }
            }
        }

        _engine = State(initialValue: engine)
        _settings = State(initialValue: settings)
        _store = State(initialValue: store)
        _notifications = State(initialValue: notifications)
        _sounds = State(initialValue: sounds)
    }

    var body: some Scene {
        MenuBarExtra(menuBarLabel) {
            TimerView(
                engine: engine,
                settings: settings,
                nextStartPhase: engine.queuedPhase ?? store.nextPhaseToStart(longBreakAfter: settings.longBreakAfterSessions),
                nextBreakPhase: store.nextBreakPhase(longBreakAfter: settings.longBreakAfterSessions)
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
        .windowResizability(.contentSize)
    }

    /// Formats the active or idle time as `"🍅 MM:SS"` for display in the menu bar.
    private var menuBarLabel: String {
        let seconds: Int
        if case .idle = engine.state {
            seconds = Int(settings.focusDuration)
        } else {
            seconds = Int(engine.timeRemaining)
        }
        return "🍅 \(String(format: "%02d:%02d", seconds / 60, seconds % 60))"
    }
}
