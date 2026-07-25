//
//  SessionIndicatorsTests.swift
//  TaskmatoTests
//

import Testing

@testable import Taskmato

@Suite("SessionIndicators(isNonIdle:onTimer:)")
struct SessionIndicatorsTests {

  @Test func idleShowsNeither() {
    let indicators = SessionIndicators(isNonIdle: false, onTimer: false)
    #expect(indicators.showStrip == false)
    #expect(indicators.showBadge == false)
  }

  @Test func idleOnTimerShowsNeither() {
    let indicators = SessionIndicators(isNonIdle: false, onTimer: true)
    #expect(indicators.showStrip == false)
    #expect(indicators.showBadge == false)
  }

  @Test func nonIdleOnTimerShowsBadgeOnly() {
    let indicators = SessionIndicators(isNonIdle: true, onTimer: true)
    #expect(indicators.showStrip == false)
    #expect(indicators.showBadge == true)
  }

  @Test func nonIdleOffTimerShowsStripAndBadge() {
    let indicators = SessionIndicators(isNonIdle: true, onTimer: false)
    #expect(indicators.showStrip == true)
    #expect(indicators.showBadge == true)
  }
}
