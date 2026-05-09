//
//  TasksTabView.swift
//  Taskmato
//

import SwiftUI

/// The tasks tab shown in the main application window.
///
/// Hosts the task picker, active task display, and inline task creation.
/// Populated in milestone P1 (local provider) and P3 (full picker UI).
struct TasksTabView: View {

  var body: some View {
    ContentUnavailableView(
      "No Task Providers",
      systemImage: "checklist",
      description: Text("Enable a task provider in Settings to see your tasks here.")
    )
  }
}

#Preview {
  TasksTabView()
}
