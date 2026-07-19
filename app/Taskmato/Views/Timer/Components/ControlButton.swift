//
//  ControlButton.swift
//  Taskmato
//

import SwiftUI

/// A compact icon-only button used in the timer controls row.
struct ControlButton: View {

  /// The accessibility label and tooltip for this button.
  let label: String
  /// SF Symbol name for the button icon.
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(label, systemImage: icon)
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
    }
    .buttonStyle(.bordered)
    .help(label)
  }
}
