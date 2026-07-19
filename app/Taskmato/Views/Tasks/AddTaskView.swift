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
  @Binding var isPresented: Bool
  var taskToEdit: TaskItem?
  /// List to pre-select in add mode. Ignored when `taskToEdit` is non-nil.
  var initialListID: String?

  @State private var title = ""
  @State private var notes = ""
  @State private var priority: TaskPriority = .none
  @State private var selectedListID: String = ""
  @State private var hasDueDate = false
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

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(sheetTitle)
        .font(.headline)

      TextField("Task title", text: $title)
        .textFieldStyle(.roundedBorder)
        .focused($isTitleFocused)
        .onSubmit { if canSubmit { submit() } }

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
          .frame(maxWidth: .infinity, alignment: .leading)
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
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        GridRow {
          Text("Due date")
            .foregroundStyle(.secondary)
          HStack {
            Toggle("", isOn: $hasDueDate)
              .labelsHidden()
            if hasDueDate {
              DatePicker("", selection: $dueDate, displayedComponents: .date)
                .labelsHidden()
            }
          }
        }
      }

      DisclosureGroup("Notes", isExpanded: $showNotes) {
        TextEditor(text: $notes)
          .frame(height: 72)
          .font(.body)
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
    .frame(width: 360)
    .onAppear {
      isTitleFocused = true
      if let task = taskToEdit {
        title = task.title
        notes = task.notes ?? ""
        priority = task.priority
        hasDueDate = task.dueDate != nil
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
        selectedListID = provider.defaultListID ?? first.id
      }
    }
  }

  // MARK: - Private

  private func submit() {
    var draft = TaskDraft()
    draft.title = title.trimmingCharacters(in: .whitespaces)
    draft.notes = notes
    draft.priority = priority
    draft.dueDate = hasDueDate ? dueDate : nil
    draft.listID = selectedListID.isEmpty ? nil : selectedListID
    isPresented = false
    if let task = taskToEdit {
      Task { try? await provider.updateTask(task.id, draft: draft) }
    } else {
      Task { try? await provider.addTask(draft) }
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
