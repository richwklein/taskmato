//
//  StatsTabView.swift
//  Taskmato
//

import SwiftUI

/// The statistics tab shown in the main application window.
///
/// Displays focus time charts and session history.
/// Populated in milestone P6 (stats visualization).
struct StatsTabView: View {

  var body: some View {
    ContentUnavailableView(
      "No Sessions Yet",
      systemImage: "chart.bar",
      description: Text("Complete a focus session to see your statistics here.")
    )
  }
}

#Preview {
  StatsTabView()
}
