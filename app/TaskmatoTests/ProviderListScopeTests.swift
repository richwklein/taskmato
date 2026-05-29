//
//  ProviderListScopeTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("ProviderListScope")
struct ProviderListScopeTests {

  // MARK: - Default behaviour

  @Test func allListsVisibleWhenScopeIsNil() {
    let scope = ProviderListScope()
    #expect(scope.isVisible("list-1"))
    #expect(scope.isVisible("list-2"))
    #expect(scope.isVisible("any-id"))
  }

  @Test func isVisibleFalseAfterHiding() {
    var scope = ProviderListScope()
    let all: Set<String> = ["list-1", "list-2", "list-3"]
    scope.setVisible("list-2", visible: false, allListIDs: all)
    #expect(!scope.isVisible("list-2"))
    #expect(scope.isVisible("list-1"))
    #expect(scope.isVisible("list-3"))
  }

  @Test func isVisibleTrueAfterShowingHidden() {
    var scope = ProviderListScope()
    let all: Set<String> = ["list-1", "list-2"]
    scope.setVisible("list-1", visible: false, allListIDs: all)
    scope.setVisible("list-1", visible: true, allListIDs: all)
    #expect(scope.isVisible("list-1"))
  }

  @Test func resetsToNilWhenAllListsVisible() {
    var scope = ProviderListScope()
    let all: Set<String> = ["list-1", "list-2"]
    scope.setVisible("list-1", visible: false, allListIDs: all)
    scope.setVisible("list-1", visible: true, allListIDs: all)
    #expect(scope.visibleListIDs == nil)
  }

  @Test func showingAlreadyVisibleListIsNoOp() {
    let original = ProviderListScope()
    var scope = original
    scope.setVisible("list-1", visible: true, allListIDs: ["list-1"])
    #expect(scope.visibleListIDs == original.visibleListIDs)
  }

  // MARK: - Codable round-trip

  @Test func encodesAndDecodesWithNilScope() throws {
    let scope = ProviderListScope()
    let data = try JSONEncoder().encode(scope)
    let decoded = try JSONDecoder().decode(ProviderListScope.self, from: data)
    #expect(decoded.visibleListIDs == nil)
  }

  @Test func encodesAndDecodesWithExplicitIDs() throws {
    var scope = ProviderListScope()
    let all: Set<String> = ["a", "b", "c"]
    scope.setVisible("b", visible: false, allListIDs: all)
    let data = try JSONEncoder().encode(scope)
    let decoded = try JSONDecoder().decode(ProviderListScope.self, from: data)
    #expect(decoded.isVisible("a"))
    #expect(!decoded.isVisible("b"))
    #expect(decoded.isVisible("c"))
  }
}
