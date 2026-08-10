//
//  AddTaskView.swift
//  Taskmato
//

import SwiftUI

/// A sheet for creating or editing a task via any writable task provider.
///
/// Pass a `taskToEdit` to open in edit mode; the form pre-fills with the task's existing
/// values and the submit button calls ``WritableTaskProvider/updateTask(_:draft:)`` instead
/// of ``WritableTaskProvider/addTask(_:)``. Pass `initialListID` to pre-select a specific
/// list in add mode (e.g. when triggered from a sidebar list context menu). When both are
/// `nil`, the sheet defaults to the provider's default list. The title field is auto-focused
/// on appear.
struct AddTaskView: View {

  var provider: any WritableTaskProvider
  var destinationResolver: TaskDestinationResolver
  @Binding var isPresented: Bool
  var errorPresenter: ErrorPresenter
  var taskToEdit: TaskItem?
  /// List to pre-select in add mode. Ignored when `taskToEdit` is non-nil.
  var initialListID: String?

  @State private var title = ""
  @State private var notes = ""
  @State private var priority: TaskPriority = .none
  @State private var selectedListID: String = ""
  @State private var sections: [String] = []
  @State private var selectedSection: String?
  @State private var hasDueDate = false
  @State private var hasDueTime = false
  @State private var dueDate = Date()
  @State private var showNotes = false
  @State private var taskLists: [TaskList] = []

  @FocusState private var isTitleFocused: Bool

  private var isEditing: Bool { taskToEdit != nil }
  private var sheetTitle: String { isEditing ? "Edit Task" : "New Task" }
  private var submitLabel: String { isEditing ? "Save" : "Add Task" }

  private var canSubmit: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private var isMarkdownCapable: Bool { provider.contentFormat == .markdown }

  /// Width reserved for row labels ("List", "Priority", "Due date", …) so the due-date row —
  /// kept outside the `Grid` above — still lines up with the Grid's own label column.
  private static let labelColumnWidth: CGFloat = 60

  var body: some View {
    VStack(alignment: .leading, spacing: .sectionGap) {
      Text(sheetTitle)
        .font(.sheetTitle)

      if !isEditing {
        Text("Adding to \(provider.displayName)")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      TextField("Task title", text: $title)
        .textFieldStyle(.roundedBorder)
        .focused($isTitleFocused)
        .onSubmit { if canSubmit { submit() } }

      if isMarkdownCapable {
        Text("Supports Markdown — **bold**, *italic*, `code`, [links]")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
        GridRow {
          Text("List")
            .foregroundStyle(.secondary)
          Picker("List", selection: $selectedListID) {
            ForEach(taskLists) { list in
              Label(list.name, systemImage: "list.bullet").tag(list.id)
            }
          }
          .labelsHidden()
          .accessibilityLabel("List")
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !sections.isEmpty {
          GridRow {
            Text("Section")
              .foregroundStyle(.secondary)
            Picker("Section", selection: $selectedSection) {
              ForEach(sections, id: \.self) { section in
                Text(section).tag(String?.some(section))
              }
            }
            .labelsHidden()
            .accessibilityLabel("Section")
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        GridRow {
          Text("Priority")
            .foregroundStyle(.secondary)
          Picker("Priority", selection: $priority) {
            ForEach(TaskPriority.allCases, id: \.self) { level in
              if let icon = level.icon {
                Label(level.displayLabel, systemImage: icon).tag(level)
              } else {
                Text(level.displayLabel).tag(level)
              }
            }
          }
          .labelsHidden()
          .accessibilityLabel("Priority")
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      // Kept out of the Grid above: the date/time chip row's width varies as chips are
      // added and removed, and Grid shares column widths across all its rows — inside the
      // Grid, that variation was dragging the List/Priority pickers wider too whenever a
      // chip appeared, visibly shifting the whole form.
      HStack(spacing: 12) {
        Text("Due date")
          .foregroundStyle(.secondary)
          .frame(width: Self.labelColumnWidth, alignment: .leading)
        HStack(spacing: 8) {
          dateChip
          if hasDueDate, provider.supportsDueTime {
            timeChip
          }
        }
      }

      DisclosureGroup("Notes", isExpanded: $showNotes) {
        TextEditor(text: $notes)
          .frame(height: 72)
          .font(.body)
          .accessibilityLabel("Notes")
      }

      HStack {
        Spacer()
        Button("Cancel") { isPresented = false }
          .keyboardShortcut(.cancelAction)
        Button(submitLabel) { submit() }
          .keyboardShortcut(.defaultAction)
          .disabled(!canSubmit)
      }
    }
    .padding()
    // Wide enough to fit both due-date chips at once (label + date chip + time chip) without
    // ever needing to grow — a fixed width that had to expand when the time chip appeared was
    // what made the form visibly shift.
    .frame(width: 420)
    .onAppear {
      isTitleFocused = true
      if let task = taskToEdit {
        title = task.title
        notes = task.notes ?? ""
        priority = task.priority
        hasDueDate = task.dueDate != nil
        hasDueTime = task.dueDateIncludesTime
        if let due = task.dueDate { dueDate = due }
        showNotes = !(task.notes ?? "").isEmpty
        selectedListID = task.list?.id ?? ""
      } else if let listID = initialListID {
        selectedListID = listID
      }
    }
    .task {
      taskLists = (try? await provider.lists()) ?? []
      if taskToEdit == nil, selectedListID.isEmpty, let first = taskLists.first {
        if let defaultID = provider.defaultListID {
          if taskLists.contains(where: { $0.id == defaultID }) {
            selectedListID = defaultID
          } else {
            selectedListID = first.id
          }
        } else {
          selectedListID = first.id
        }
      }
    }
    .task(id: selectedListID) {
      guard !selectedListID.isEmpty else {
        sections = []
        selectedSection = nil
        return
      }
      let list = TaskList(id: selectedListID, providerID: provider.id, name: "")
      sections = (try? await provider.sections(in: list)) ?? []
      // No "None" option: once a file has at least one heading, a task inserted anywhere below
      // it reads back as belonging to that heading anyway (Obsidian has no way to mark a task as
      // deliberately section-less past that point), so the picker only offers real targets.
      let editingSection = (taskToEdit?.list?.id == selectedListID ? taskToEdit?.section : nil)
      if let editingSection, sections.contains(editingSection) {
        selectedSection = editingSection
      } else {
        selectedSection = sections.first
      }
    }
  }

  // MARK: - Due date / time chips

  /// A capsule showing the selected due date with a clear button, or an "Add Date" button when
  /// no due date is set — mirroring Reminders.app's date-chip affordance.
  @ViewBuilder
  private var dateChip: some View {
    if hasDueDate {
      HStack(spacing: 4) {
        Image(systemName: "calendar")
        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
          .labelsHidden()
          .datePickerStyle(.compact)
          .fixedSize()
        Button {
          hasDueDate = false
          hasDueTime = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove due date")
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    } else {
      Button {
        hasDueDate = true
        dueDate = Date()
      } label: {
        Label("Add Date", systemImage: "calendar")
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  /// A capsule showing the selected due time with a clear button, or an "Add Time" button when
  /// no due time is set. Adding a time seeds it from the current wall-clock time rather than
  /// whatever time-of-day `dueDate` already happens to carry (e.g. midnight from a date-only
  /// value), so the picker opens on a meaningful default.
  @ViewBuilder
  private var timeChip: some View {
    if hasDueTime {
      HStack(spacing: 4) {
        Image(systemName: "clock")
        DatePicker("Due time", selection: $dueDate, displayedComponents: .hourAndMinute)
          .labelsHidden()
          .datePickerStyle(.compact)
          .fixedSize()
        Button {
          hasDueTime = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove due time")
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    } else {
      Button {
        hasDueTime = true
        dueDate = Self.mergingCurrentTime(into: dueDate)
      } label: {
        Label("Add Time", systemImage: "clock")
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  /// Returns `date` with its hour/minute replaced by the current wall-clock time.
  private static func mergingCurrentTime(into date: Date) -> Date {
    let calendar = Calendar.current
    let nowComponents = calendar.dateComponents([.hour, .minute], from: Date())
    return calendar.date(
      bySettingHour: nowComponents.hour ?? 0,
      minute: nowComponents.minute ?? 0,
      second: 0,
      of: date
    ) ?? date
  }

  // MARK: - Private

  private func submit() {
    var draft = TaskDraft()
    draft.title = title.trimmingCharacters(in: .whitespaces)
    draft.notes = notes
    draft.priority = priority
    if hasDueDate {
      draft.dueDate = hasDueTime ? dueDate : Calendar.current.startOfDay(for: dueDate)
      draft.dueDateIncludesTime = hasDueTime
    } else {
      draft.dueDate = nil
      draft.dueDateIncludesTime = false
    }
    draft.listID = selectedListID.isEmpty ? nil : selectedListID
    draft.section = selectedSection
    draft.format = provider.contentFormat
    // Dismiss only after the write completes — dismissing first (as this used to) races the
    // sheet's `isAddingTask`-driven refresh against the provider write: for an in-process
    // provider like LocalProvider the in-memory mutation usually beats the refresh anyway, but
    // for RemindersProvider the refresh re-fetches from EventKit, which can lose that race and
    // show a list missing the task that was just added.
    if let task = taskToEdit {
      Task {
        await errorPresenter.attempt(AppLabels.Error.updateFailed) {
          try await provider.updateTask(task.id, draft: draft)
        }
        isPresented = false
      }
    } else {
      Task {
        await errorPresenter.attempt(AppLabels.Error.addFailed) {
          let destination = try await destinationResolver.resolve(
            providerID: provider.id, listID: draft.listID)
          var routedDraft = draft
          routedDraft.listID = destination.listID
          try await destination.provider.addTask(routedDraft)
        }
        isPresented = false
      }
    }
  }
}

// MARK: - TaskPriority display

extension TaskPriority {
  /// Short label used in the priority picker inside ``AddTaskView``.
  fileprivate var displayLabel: String {
    switch self {
    case .none: return "None"
    case .lowest: return "Lowest"
    case .low: return "Low"
    case .medium: return "Medium"
    case .high: return "High"
    case .highest: return "Highest"
    }
  }

}
