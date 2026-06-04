//
//  AddTaskView.swift
//  Taskmato
//

import SwiftUI

/// A sheet for creating a new task in ``LocalProvider``.
///
/// Displayed as a modal sheet from the Tasks tab when the local provider is active.
/// The title field is auto-focused on appear. Submitting with an empty title is disabled.
struct AddTaskView: View {

  var provider: LocalProvider
  @Binding var isPresented: Bool

  @State private var title = ""
  @State private var notes = ""
  @State private var priority: TaskPriority = .none
  @State private var selectedListID: String = ""
  @State private var hasDueDate = false
  @State private var dueDate = Date()
  @State private var showNotes = false

  @FocusState private var isTitleFocused: Bool

  private var canSubmit: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("New Task")
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
            ForEach(provider.taskLists) { list in
              Label(list.name, systemImage: "list.bullet").tag(list.id.uuidString)
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
        Button("Add Task") { submit() }
          .keyboardShortcut(.defaultAction)
          .disabled(!canSubmit)
      }
    }
    .padding()
    .frame(width: 360)
    .onAppear {
      isTitleFocused = true
      selectedListID = provider.defaultListID ?? provider.taskLists.first?.id.uuidString ?? ""
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
    provider.addTask(draft)
    isPresented = false
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
