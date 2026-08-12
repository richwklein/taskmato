//
//  ProviderTintTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("ProviderTint")
struct ProviderTintTests {

  // MARK: - Raw value stability (rename guard — these values are now on disk)

  @Test func rawValuesAreStable() {
    #expect(ProviderTint.blue.rawValue == "blue")
    #expect(ProviderTint.green.rawValue == "green")
    #expect(ProviderTint.orange.rawValue == "orange")
    #expect(ProviderTint.purple.rawValue == "purple")
    #expect(ProviderTint.gray.rawValue == "gray")
  }

  // MARK: - Lenient decode

  @Test func unknownRawValueDecodesToGray() throws {
    let data = Data("\"chartreuse\"".utf8)
    let decoded = try JSONDecoder().decode(ProviderTint.self, from: data)
    #expect(decoded == .gray)
  }

  // MARK: - Encode/decode round-trip

  @Test func everyCaseRoundTripsThroughEncodeDecode() throws {
    for tint in [ProviderTint.blue, .green, .orange, .purple, .gray] {
      let data = try JSONEncoder().encode(tint)
      let decoded = try JSONDecoder().decode(ProviderTint.self, from: data)
      #expect(decoded == tint)
    }
  }
}
