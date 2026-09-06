//
//  ProEntitlementTests.swift
//  TaskmatoTests
//

import Testing

@testable import Taskmato

@Suite("ProEntitlement")
@MainActor
struct ProEntitlementTests {

  @Test func defaultsToLocked() {
    let entitlement = ProEntitlement()
    #expect(entitlement.isPro == false)
  }

  @Test func updateUnlocksAndRelocks() {
    let entitlement = ProEntitlement()
    entitlement.update(isPro: true)
    #expect(entitlement.isPro == true)
    entitlement.update(isPro: false)
    #expect(entitlement.isPro == false)
  }
}
