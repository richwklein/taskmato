//
//  SurfaceEmphasisTests.swift
//  TaskmatoTests
//

import Testing

@testable import Taskmato

@Suite("SurfaceEmphasis")
struct SurfaceEmphasisTests {

  // MARK: - Resolution

  @Test func unselectedResolvesToNormalRegardlessOfFocus() {
    #expect(SurfaceEmphasis(isSelected: false, isSelectionFocused: false) == .normal)
    #expect(SurfaceEmphasis(isSelected: false, isSelectionFocused: true) == .normal)
  }

  @Test func selectedAndUnfocusedResolvesToUnemphasizedSelection() {
    #expect(SurfaceEmphasis(isSelected: true, isSelectionFocused: false) == .unemphasizedSelection)
  }

  @Test func selectedAndFocusedResolvesToEmphasizedSelection() {
    #expect(SurfaceEmphasis(isSelected: true, isSelectionFocused: true) == .emphasizedSelection)
  }

  // MARK: - Selection indicator

  @Test func onlyEmphasizedSelectionShowsSelection() {
    #expect(SurfaceEmphasis.normal.showsSelection == false)
    #expect(SurfaceEmphasis.unemphasizedSelection.showsSelection == false)
    #expect(SurfaceEmphasis.emphasizedSelection.showsSelection == true)
  }
}
