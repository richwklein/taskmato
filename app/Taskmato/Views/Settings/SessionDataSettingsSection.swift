//
//  SessionDataSettingsSection.swift
//  Taskmato
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings controls for manual, free session-history export and import.
struct SessionDataSettingsSection: View {

  @Bindable var controller: SessionPortabilityController
  @State private var showsExportWarning = false
  @State private var showsImporter = false

  var body: some View {
    Section("Data") {
      Text("Session History")
        .font(.headline)
      Text(
        "Export and import saved focus sessions and breaks. Settings, account credentials, provider "
          + "setup, and timer state stay on this Mac."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack {
        Button("Export…") { showsExportWarning = true }
          .disabled(isBusy)
        Button("Import…") { showsImporter = true }
          .disabled(isBusy)
      }

      stateDetail
    }
    .alert("Export unencrypted session history?", isPresented: $showsExportWarning) {
      Button("Choose Location…") { controller.prepareExport() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "The file includes session dates and durations, task names and identifiers, and provider "
          + "identifiers. Anyone with the file can read it. Settings, account credentials, provider "
          + "setup, recent tasks, and timer state aren’t included."
      )
    }
    .fileImporter(
      isPresented: $showsImporter, allowedContentTypes: [.json]
    ) { result in
      if case .success(let url) = result { controller.preflightImport(from: url) }
    }
    .fileExporter(
      isPresented: exportPresentation,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "Taskmato Sessions \(Self.fileDate.string(from: Date())).taskmato-sessions"
    ) { result in
      if case .failure = result { controller.dismiss() } else { controller.dismiss() }
    }
    .confirmationDialog(
      "Import session history?", isPresented: mergePresentation, titleVisibility: .visible
    ) {
      Button("Import") { controller.confirmImport() }
        .disabled(mergePlan?.preview.result.isNoOp ?? true)
      Button("Cancel", role: .cancel) { controller.dismiss() }
    } message: {
      if let plan = mergePlan { Text(previewMessage(for: plan)) }
    }
    .alert(resultTitle, isPresented: resultPresentation) {
      Button(resultButtonTitle) { controller.dismiss() }
    } message: {
      Text(resultMessage)
    }
  }

  @ViewBuilder
  private var stateDetail: some View {
    switch controller.state {
    case .preparingExport: ProgressView("Preparing export…")
    case .preflightingImport: ProgressView("Checking file…")
    case .importing: ProgressView("Importing…")
    case .awaitingConfirmation(let plan):
      Text(previewMessage(for: plan)).font(.caption).foregroundStyle(.secondary)
    case .completed(let result):
      Text(completionMessage(for: result)).font(.caption).foregroundStyle(.secondary)
    case .failed(let message): Text(message).font(.caption).foregroundStyle(.red)
    case .idle, .readyToExport: EmptyView()
    }
  }

  private var isBusy: Bool {
    switch controller.state {
    case .preparingExport, .preflightingImport, .importing: true
    case .idle, .readyToExport, .awaitingConfirmation, .completed, .failed: false
    }
  }

  private var exportPresentation: Binding<Bool> {
    Binding(
      get: {
        if case .readyToExport = controller.state { return true }
        return false
      },
      set: { if !$0 { controller.dismiss() } })
  }

  private var exportDocument: SessionHistoryFile? {
    if case .readyToExport(let document) = controller.state { return document }
    return nil
  }

  private var mergePresentation: Binding<Bool> {
    Binding(
      get: {
        if case .awaitingConfirmation = controller.state { return true }
        return false
      },
      set: { if !$0 { controller.dismiss() } })
  }

  private var mergePlan: SessionPortabilityController.SessionHistoryImportPlan? {
    if case .awaitingConfirmation(let plan) = controller.state { return plan }
    return nil
  }

  private var resultPresentation: Binding<Bool> {
    Binding(
      get: {
        if case .completed = controller.state { return true }
        if case .failed = controller.state { return true }
        return false
      },
      set: { if !$0 { controller.dismiss() } })
  }

  private var resultMessage: String {
    switch controller.state {
    case .completed(let result): return completionMessage(for: result)
    case .failed(let message): return message
    case .idle, .preparingExport, .readyToExport, .preflightingImport, .awaitingConfirmation,
      .importing:
      return ""
    }
  }

  private var resultTitle: String {
    switch controller.state {
    case .completed: return "Import Complete"
    case .failed: return "Session History"
    case .idle, .preparingExport, .readyToExport, .preflightingImport, .awaitingConfirmation,
      .importing:
      return ""
    }
  }

  private var resultButtonTitle: String {
    if case .completed = controller.state { return "Done" }
    return "OK"
  }

  private func previewMessage(
    for plan: SessionPortabilityController.SessionHistoryImportPlan
  ) -> String {
    let result = plan.preview.result
    var sentences = mergeSentences(for: result, tense: .future)

    if sentences.isEmpty {
      sentences.append("There are no sessions to import.")
    }
    if let range = plan.preview.dateRange {
      sentences.append("Includes sessions from \(Self.dateRange(range)).")
    }

    return sentences.joined(separator: " ")
  }

  private func completionMessage(for result: SessionMergeResult) -> String {
    let sentences = mergeSentences(for: result, tense: .past)
    return sentences.isEmpty ? "No sessions were imported." : sentences.joined(separator: " ")
  }

  /// Distinguishes an import preview from a completed-import summary.
  private enum MergeMessageTense: Equatable {
    /// Describes changes that will occur after confirmation.
    case future
    /// Describes changes that have already completed.
    case past
  }

  private func mergeSentences(
    for result: SessionMergeResult, tense: MergeMessageTense
  ) -> [String] {
    var sentences: [String] = []

    if result.inserted > 0 {
      let count = Self.sessionCount(result.inserted)
      sentences.append(tense == .future ? "\(count) will be added." : "Added \(count).")
    }
    if result.updated > 0 {
      let count = Self.sessionCount(result.updated)
      sentences.append(tense == .future ? "\(count) will be updated." : "Updated \(count).")
    }
    if result.skipped > 0 {
      let count = Self.sessionCount(result.skipped)
      sentences.append(tense == .future ? "\(count) won’t change." : "\(count) stayed unchanged.")
    }
    if result.conflicts > 0 {
      let count = Self.sessionCount(result.conflicts)
      let detail = "\(count) with matching timestamps but different details"
      sentences.append(
        tense == .future ? "\(detail) will stay unchanged." : "\(detail) stayed unchanged.")
    }

    return sentences
  }

  private static let fileDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static func dateRange(_ dates: ClosedRange<Date>) -> String {
    let formatter = DateIntervalFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: dates.lowerBound, to: dates.upperBound)
  }

  private static func sessionCount(_ count: Int) -> String {
    "\(count) \(count == 1 ? "session" : "sessions")"
  }
}
