//
//  RemindersProviderListConfigurationTests.swift
//  TaskmatoTests
//

import EventKit
import Foundation
import Synchronization
import Testing

@testable import Taskmato

@Suite("RemindersProvider — listConfiguration")
@MainActor
struct RemindersProviderListConfigurationTests {
  private func makeProvider(patterns: [String]) -> RemindersProvider {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let settings = SettingsStore(defaults: defaults)
    settings[SettingsStore.Keys.remindersListPatterns] = patterns
    let store = FakeRemindersEventStore()
    return RemindersProvider(store: store, settings: settings)
  }

  @Test func changingListPatternsFiresObservationThroughExistential() {
    let provider = makeProvider(patterns: ["Work"])
    let existential: any WritableTaskProvider = provider
    let fired = Mutex(false)

    withObservationTracking {
      _ = existential.listConfiguration
    } onChange: {
      fired.withLock { $0 = true }
    }

    provider.setListPatterns(["Personal"])

    #expect(fired.withLock { $0 })
  }

  @Test func reorderedPatterns_tokenIsEqual() {
    let provider = makeProvider(patterns: ["Work", "Personal"])
    let before = provider.listConfiguration
    provider.setListPatterns(["Personal", "Work"])
    #expect(before == provider.listConfiguration)
  }

  @Test func differentPatterns_tokenIsNotEqual() {
    let provider = makeProvider(patterns: ["Work"])
    let before = provider.listConfiguration
    provider.setListPatterns(["Personal"])
    #expect(before != provider.listConfiguration)
  }
}
