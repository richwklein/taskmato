//
//  TaskDisambiguationSheet.swift
//  Taskmato
//

import SwiftUI

/// A disambiguation candidate's task plus the display values its provider row needs.
///
/// Mirrors ``TaskProviderLink``'s pattern of resolving provider display values as a plain,
/// testable value — keeping display logic out of the `TaskDisambiguationSheet` view.
struct DisambiguationMatch: Identifiable {

  /// The candidate task.
  let task: TaskItem

  /// The owning provider's display name, or a neutral placeholder when unresolved.
  let providerName: String

  /// The owning provider's SF Symbol icon, or a neutral placeholder when unresolved.
  let icon: String

  /// The task's stable reference, used to identify each row in the sheet's list.
  var id: TaskRef { task.id }

  /// The task's title, shown as the row's primary label.
  var title: String { task.title }
}

@MainActor
extension DisambiguationMatch {

  /// Resolves `task`'s provider display values from `registry`, with a neutral placeholder
  /// when the provider can't be resolved.
  /// - Parameters:
  ///   - task: The candidate task to resolve.
  ///   - registry: The registry used to look up the owning provider's display values.
  init(task: TaskItem, registry: ProviderRegistry) {
    let provider = registry.provider(for: task.id)
    self.task = task
    self.providerName = provider?.displayName ?? "Unknown provider"
    self.icon = provider?.icon ?? "questionmark.circle"
  }
}

/// A sheet presenting multiple same-titled task matches from a `taskmato://` deep link, letting
/// the user pick which one to start a focus session on.
///
/// Decoupled from ``URLSchemeHandler`` via closures so it stays testable and previewable in
/// isolation. Every row shows the owning provider's icon and name alongside the task title —
/// `.confirmationDialog`'s text-only buttons couldn't tell same-titled tasks from different
/// providers apart. When `adHocTitle` is non-`nil`, a trailing "Create new" row lets the user
/// create a fresh task instead of picking an existing match.
struct TaskDisambiguationSheet: View {

  /// The candidate matches, each shown as a tappable row.
  let matches: [DisambiguationMatch]

  /// The ad-hoc title to offer creating as a new task, or `nil` to hide that row.
  let adHocTitle: String?

  /// Called when the user taps a match row.
  let onSelect: (TaskItem) -> Void

  /// Called when the user taps the "Create new" row.
  let onCreateNew: () -> Void

  /// Called when the user cancels the sheet.
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: .stackTight) {
        Text("Multiple tasks match")
          .font(.headline)
        Text("Choose which task to start a focus session on.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding([.horizontal, .top], .screenPadding)
      .padding(.bottom, .contentGap)

      List {
        ForEach(matches) { match in
          Button {
            onSelect(match.task)
          } label: {
            matchRow(match)
          }
          .buttonStyle(.plain)
        }
        if let adHocTitle {
          Button {
            onCreateNew()
          } label: {
            Label("Create new \"\(adHocTitle)\"", systemImage: "plus.circle")
          }
          .buttonStyle(.plain)
        }
      }

      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { onCancel() }
          .keyboardShortcut(.cancelAction)
      }
      .padding(.horizontal, .screenPadding)
      .padding(.vertical, .contentGap)
    }
    .frame(minWidth: 360, minHeight: 320)
  }

  /// A single tappable row showing a match's provider icon, task title, and provider name.
  @ViewBuilder
  private func matchRow(_ match: DisambiguationMatch) -> some View {
    HStack(spacing: .iconLabel) {
      Image(systemName: match.icon)
      VStack(alignment: .leading, spacing: .stackTight) {
        Text(match.title)
        Text(match.providerName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .contentShape(Rectangle())
    .padding(.vertical, .rowVertical)
  }
}

#if DEBUG
  #Preview {
    let obsidianMatch = DisambiguationMatch(
      task: TaskItem(
        id: TaskRef(providerID: "obsidian", nativeID: "1"),
        title: "Standup",
        notes: nil,
        format: .plainText,
        priority: .none,
        dueDate: nil,
        scheduledDate: nil,
        startDate: nil,
        list: nil,
        section: nil,
        sourceURL: nil
      ),
      providerName: "Obsidian",
      icon: "note.text"
    )
    let remindersMatch = DisambiguationMatch(
      task: TaskItem(
        id: TaskRef(providerID: "reminders", nativeID: "2"),
        title: "Standup",
        notes: nil,
        format: .plainText,
        priority: .none,
        dueDate: nil,
        scheduledDate: nil,
        startDate: nil,
        list: nil,
        section: nil,
        sourceURL: nil
      ),
      providerName: "Reminders",
      icon: "checklist"
    )
    TaskDisambiguationSheet(
      matches: [obsidianMatch, remindersMatch],
      adHocTitle: "Standup",
      onSelect: { _ in },
      onCreateNew: {},
      onCancel: {}
    )
  }
#endif
