//
//  SurfaceEmphasis.swift
//  Taskmato
//

/// Whether a selectable surface draws a selection indicator, so its neighbors — the list's row
/// background or a card's border — can resolve to the right treatment.
///
/// A plain, SwiftUI-free token — the sibling of ``ProviderTint`` — so the resolution logic is
/// testable on its own. ``SurfaceEmphasis+Style`` maps each case to a concrete `Color`. Content
/// itself never changes color with selection; only the surface does.
enum SurfaceEmphasis: Equatable {

  /// An ordinary, unselected card, row, or stat surface.
  case normal

  /// A selected surface that owns keyboard focus — draws the band or ring.
  case emphasizedSelection

  /// A selected surface whose focus has moved elsewhere — draws nothing, matching Reminders.
  case unemphasizedSelection

  /// Resolves the emphasis for a selectable surface from its selection and focus state.
  init(isSelected: Bool, isSelectionFocused: Bool) {
    guard isSelected else {
      self = .normal
      return
    }
    self = isSelectionFocused ? .emphasizedSelection : .unemphasizedSelection
  }

  /// Whether this surface draws a selection indicator — the list's band or the card's ring.
  ///
  /// Only the focused case does. Selection is ephemeral and its commands are unreachable while
  /// focus sits elsewhere, so an unfocused row reads as unselected rather than half-selected.
  var showsSelection: Bool { self == .emphasizedSelection }
}
