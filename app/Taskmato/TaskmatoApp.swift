//
//  TaskmatoApp.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
import SwiftUI

@main
struct TaskmatoApp: App {

  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var composition: AppComposition

  init() {
    let composition = AppComposition()
    _composition = State(initialValue: composition)
    let appDel = _appDelegate.wrappedValue
    appDel.bootstrap = { appDel.wire(urlHandler: composition.urlHandler) }
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarPopoverView(
        engine: composition.engine,
        settings: composition.settings,
        store: composition.store,
        selectionStore: composition.selectionStore,
        registry: composition.registry,
        nav: composition.nav,
        nextStartPhase: composition.engine.queuedPhase ?? .focus,
        nextBreakPhase: composition.engine.nextBreakPhase(
          longBreakAfter: composition.settings.longBreakAfterSessions)
      )
      .confirmationDialog(
        "Multiple tasks match — which one?",
        isPresented: Binding(
          get: { composition.urlHandler.pendingDisambiguation != nil },
          set: { if !$0 { composition.urlHandler.pendingDisambiguation = nil } }
        ),
        titleVisibility: .visible,
        presenting: composition.urlHandler.pendingDisambiguation
      ) { matches in
        ForEach(matches.prefix(4)) { task in
          Button(task.title) {
            composition.selectionStore.select(task)
            composition.urlHandler.pendingDisambiguation = nil
            composition.nav.showTimerInMainWindow()
          }
        }
        if let params = composition.urlHandler.pendingAdHocParams {
          Button("Create new \"\(params.title)\"") {
            Task {
              let task = await composition.urlHandler.makeAdHocTask(from: params)
              composition.selectionStore.select(task)
              composition.urlHandler.pendingDisambiguation = nil
              composition.nav.showTimerInMainWindow()
            }
          }
        }
        Button("Cancel", role: .cancel) {
          composition.urlHandler.pendingDisambiguation = nil
          composition.urlHandler.pendingAdHocParams = nil
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image("MenuIcon")
        Text(menuBarLabel)
      }
    }
    .menuBarExtraStyle(.window)

    Window(Bundle.main.appName, id: "main") {
      MainWindowView(
        engine: composition.engine,
        settings: composition.settings,
        store: composition.store,
        selectionStore: composition.selectionStore,
        registry: composition.registry,
        nav: composition.nav
      )
    }
    .defaultSize(width: 480, height: 520)
    .windowResizability(.contentMinSize)
    .commands {
      TaskmatoCommands(nav: composition.nav, settings: composition.settings)
    }

    Settings {
      SettingsView(
        settings: composition.settings,
        selectionStore: composition.selectionStore,
        registry: composition.registry,
        notifications: composition.notifications
      )
    }
    .windowResizability(.contentSize)
  }

  /// Formats the active or idle time as `"MM:SS"` for display in the menu bar.
  private var menuBarLabel: String {
    let seconds: Int
    if case .idle = composition.engine.state {
      let phase = composition.engine.queuedPhase ?? SessionPhase.focus
      switch phase {
      case .focus: seconds = Int(composition.settings.focusDuration)
      case .shortBreak: seconds = Int(composition.settings.shortBreakDuration)
      case .longBreak: seconds = Int(composition.settings.longBreakDuration)
      }
    } else {
      seconds = Int(composition.engine.timeRemaining)
    }
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
}

// MARK: - Commands

/// Menu commands and keyboard shortcuts for the main application window.
struct TaskmatoCommands: Commands {

  @FocusedValue(\.selectedTab) private var selectedTab
  @FocusedValue(\.focusSearch) private var focusSearch
  @FocusedValue(\.addTask) private var addTask
  @FocusedValue(\.toggleCompleted) private var toggleCompleted
  @FocusedValue(\.toggleCompletedTitle) private var toggleCompletedTitle
  @FocusedValue(\.toggleCompletedIcon) private var toggleCompletedIcon
  @FocusedValue(\.timerToggle) private var timerToggle
  @FocusedValue(\.timerToggleTitle) private var timerToggleTitle
  @FocusedValue(\.timerSkip) private var timerSkip
  @FocusedValue(\.timerStop) private var timerStop

  /// The navigation model used to switch tabs from the View menu.
  var nav: MainNavigation
  /// App settings used to read and write layout and sort state for View menu checkmarks.
  @Bindable var settings: AppSettings

  var body: some Commands {
    // File → New Task (⌘N); disabled when no writable provider is available.
    CommandGroup(replacing: .newItem) {
      Button(AppLabels.Task.add.title) { addTask?() }
        .keyboardShortcut("n")
        .disabled(addTask == nil)
    }
    // Edit → Find… (⌘F); disabled when not on the Tasks tab.
    CommandGroup(after: .textEditing) {
      Divider()
      Button(AppLabels.View.find.title) { focusSearch?() }
        .keyboardShortcut("f")
        .disabled(focusSearch == nil)
    }
    // View → Suppress the default broken sidebar toggle; our replacement lives at the bottom below.
    CommandGroup(replacing: .sidebar) {}
    // View → tab navigation (⌘1/2/3), layout, completed toggle (⌘⇧C), Sort By, then Show/Hide
    // Sidebar (⌘⌃S) — placed last so it sits directly above the system "Enter Full Screen" item.
    CommandGroup(after: .sidebar) {
      Divider()
      Button {
        nav.showTasks()
      } label: {
        Label(AppLabels.Tab.tasks.title, systemImage: nav.selectedTab == .tasks ? "checkmark" : "")
      }
      .keyboardShortcut("1")
      Button {
        nav.showTimer()
      } label: {
        Label(AppLabels.Tab.timer.title, systemImage: nav.selectedTab == .timer ? "checkmark" : "")
      }
      .keyboardShortcut("2")
      Button {
        nav.showStats()
      } label: {
        Label(AppLabels.Tab.stats.title, systemImage: nav.selectedTab == .stats ? "checkmark" : "")
      }
      .keyboardShortcut("3")
      Divider()
      Picker("Layout", selection: $settings.taskPickerLayout) {
        Label(AppLabels.View.listLayout.title, systemImage: AppLabels.View.listLayout.systemImage)
          .tag(TaskPickerLayout.list)
        Label(AppLabels.View.gridLayout.title, systemImage: AppLabels.View.gridLayout.systemImage)
          .tag(TaskPickerLayout.grid)
      }
      .pickerStyle(.inline)
      .disabled(selectedTab != .tasks)
      Divider()
      Button {
        toggleCompleted?()
      } label: {
        Label(
          toggleCompletedTitle ?? AppLabels.View.showCompleted.title,
          systemImage: toggleCompletedIcon ?? AppLabels.View.showCompleted.systemImage
        )
      }
      .keyboardShortcut("c", modifiers: [.command, .shift])
      .disabled(toggleCompleted == nil)
      Divider()
      Menu {
        ForEach(TaskSortField.allCases, id: \.self) { field in
          Button {
            settings.taskSortField = field
            settings.taskSortDirection = field.defaultSortDirection
          } label: {
            Label(
              field.displayName,
              systemImage: settings.taskSortField == field ? "checkmark" : "")
          }
        }
        Divider()
        Button {
          settings.taskSortDirection = .ascending
        } label: {
          Label(
            settings.taskSortField.ascendingLabel,
            systemImage: settings.taskSortDirection == .ascending ? "checkmark" : "")
        }
        Button {
          settings.taskSortDirection = .descending
        } label: {
          Label(
            settings.taskSortField.descendingLabel,
            systemImage: settings.taskSortDirection == .descending ? "checkmark" : "")
        }
      } label: {
        Label(AppLabels.View.sort.title, systemImage: AppLabels.View.sort.systemImage)
      }
      .disabled(selectedTab != .tasks)
      Divider()
      let sidebarSpec = nav.sidebarVisible ? AppLabels.View.hideSidebar : AppLabels.View.showSidebar
      Button {
        nav.sidebarVisible.toggle()
      } label: {
        Label(sidebarSpec.title, systemImage: sidebarSpec.systemImage)
      }
      .keyboardShortcut("s", modifiers: [.command, .control])
      .disabled(selectedTab != .tasks)
    }
    // Timer menu — Start/Pause/Resume (⌘⏎), Skip Phase (⌘K), Stop (⌘.).
    CommandMenu("Timer") {
      Button(timerToggleTitle ?? AppLabels.Timer.start.title) { timerToggle?() }
        .keyboardShortcut(.return)
        .disabled(timerToggle == nil)
      Button(AppLabels.Timer.skip.title) { timerSkip?() }
        .keyboardShortcut("k")
        .disabled(timerSkip == nil)
      Divider()
      Button(AppLabels.Timer.stop.title) { timerStop?() }
        .keyboardShortcut(".", modifiers: .command)
        .disabled(timerStop == nil)
    }
  }
}
