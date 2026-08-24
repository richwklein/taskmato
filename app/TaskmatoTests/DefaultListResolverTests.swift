//
//  DefaultListResolverTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("DefaultListResolver")
struct DefaultListResolverTests {

  private let work = TaskList(id: "work", providerID: "reminders", name: "Work")
  private let personal = TaskList(id: "personal", providerID: "reminders", name: "Personal")

  @Test func storedDefaultPresentAmongLists_returnsStoredDefault() {
    let resolved = DefaultListResolver.resolve(among: [work, personal], storedDefault: "personal")
    #expect(resolved == "personal")
  }

  @Test func storedDefaultExcludedFromLists_returnsFirstList() {
    let resolved = DefaultListResolver.resolve(among: [work, personal], storedDefault: "shopping")
    #expect(resolved == "work")
  }

  @Test func noStoredDefault_returnsFirstList() {
    let resolved = DefaultListResolver.resolve(among: [work, personal], storedDefault: nil)
    #expect(resolved == "work")
  }

  @Test func emptyLists_returnsNil() {
    let resolved = DefaultListResolver.resolve(among: [], storedDefault: "work")
    #expect(resolved == nil)
  }
}
