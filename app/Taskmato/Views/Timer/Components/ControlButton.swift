//
//  ControlButton.swift
//  Taskmato
//

import SwiftUI

/// A circular icon-only button used in the timer controls row.
///
/// Renders with the system bordered styles clipped to a circle: the prominent (tinted)
/// variant marks the primary action, the plain bordered variant the secondary ones. The
/// diameter is supplied by the caller so the same button scales between the compact
/// popover and the larger window Timer surface.
struct ControlButton: View {

  /// The accessibility label and tooltip for this button.
  let label: String
  /// SF Symbol name for the button icon.
  let icon: String
  /// Whether to render the tinted (prominent) style used for the primary action.
  var isProminent: Bool = false
  /// The icon frame's width and height; the bordered style adds its own padding.
  var diameter: CGFloat = 44
  let action: () -> Void

  var body: some View {
    styledButton
      .clipShape(Circle())
      .help(label)
      .accessibilityLabel(label)
  }

  @ViewBuilder
  private var styledButton: some View {
    if isProminent {
      Button(action: action) { iconImage }
        .buttonStyle(.borderedProminent)
    } else {
      Button(action: action) { iconImage }
        .buttonStyle(.bordered)
    }
  }

  private var iconImage: some View {
    Image(systemName: icon)
      .frame(width: diameter, height: diameter)
  }
}
