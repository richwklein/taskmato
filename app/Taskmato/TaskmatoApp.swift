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
        presenter: composition.timerPresenter,
        statsViewModel: composition.statsViewModel,
        selectionStore: composition.selectionStore,
        nav: composition.nav
      )
    } label: {
      HStack(spacing: 4) {
        Image("MenuIcon")
        Text(composition.timerPresenter.label)
      }
    }
    .menuBarExtraStyle(.window)

    Window(Bundle.main.appName, id: "main") {
      MainWindowView(
        presenter: composition.timerPresenter,
        engine: composition.engine,
        settings: composition.settings,
        statsViewModel: composition.statsViewModel,
        selectionStore: composition.selectionStore,
        registry: composition.registry,
        queryService: composition.queryService,
        sidebarSelection: composition.sidebarSelection,
        nav: composition.nav
      )
      // Task-disambiguation for `taskmato://` deep links presents on the main window, the
      // app's primary surface (design doc 0008, D5). `URLSchemeHandler` opens the window
      // when a match is ambiguous so this dialog has a surface to appear on.
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
    }
    .defaultSize(width: 480, height: 520)
    .windowResizability(.contentMinSize)
    .commands {
      TaskmatoCommands(
        nav: composition.nav, settings: composition.settings, registry: composition.registry)
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
}

// MARK: - Commands

/// Menu commands and keyboard shortcuts for the main application window.
struct TaskmatoCommands: Commands {

  @FocusedValue(\.destination) private var destination
  @FocusedValue(\.focusSearch) private var focusSearch
  @FocusedValue(\.addTask) private var addTask
  @FocusedValue(\.toggleCompleted) private var toggleCompleted
  @FocusedValue(\.toggleCompletedTitle) private var toggleCompletedTitle
  @FocusedValue(\.toggleCompletedIcon) private var toggleCompletedIcon
  @FocusedValue(\.timerToggle) private var timerToggle
  @FocusedValue(\.timerToggleTitle) private var timerToggleTitle
  @FocusedValue(\.timerSkip) private var timerSkip
  @FocusedValue(\.timerStop) private var timerStop

  /// The navigation model used to switch destinations from the View menu.
  var nav: MainNavigation
  /// App settings used to read and write layout and sort state for View menu checkmarks.
  @Bindable var settings: AppSettings
  /// The provider registry used to populate the File → Add Provider submenu.
  var registry: ProviderRegistry

  /// Whether the focused window is showing a task-scope destination (Today or a list).
  ///
  /// Read from the focused value so task-scope commands gate on what the window shows,
  /// which absorbs the #426 pattern where Layout/Sort stayed enabled off the task surface.
  private var isTaskScope: Bool {
    if case .today = destination { return true }
    if case .list = destination { return true }
    return false
  }

  /// Whether the current navigation destination is any Stats scope.
  private var isStatsDestination: Bool {
    if case .stats = nav.destination { return true }
    return false
  }

  /// Registered providers that are not currently enabled.
  private var disabledProviders: [any TaskProvider] {
    registry.providers.filter { !registry.isEnabled($0.id) }
  }

  var body: some Commands {
    // File → New Task (⌘N) and Add Provider ▸.
    CommandGroup(replacing: .newItem) {
      Button(AppLabels.Task.add.title) { addTask?() }
        .keyboardShortcut("n")
        .disabled(addTask == nil)

      // Disabled placeholder when every provider is already enabled — an empty submenu
      // reads as broken, a greyed item reads as "nothing to add". Enabling here is picked up
      // by the sidebar, which expands the section, opens configuration, and loads lists.
      if disabledProviders.isEmpty {
        Button(AppLabels.Sidebar.addProvider.title) {}
          .disabled(true)
      } else {
        Menu(AppLabels.Sidebar.addProvider.title) {
          ForEach(disabledProviders, id: \.id) { provider in
            Button(provider.displayName) { registry.enable(provider) }
          }
        }
      }
    }
    // Edit → Find… (⌘F); disabled when not on a task destination (focusSearch is only
    // published by the task detail surface).
    CommandGroup(after: .textEditing) {
      Divider()
      Button(AppLabels.View.find.title) { focusSearch?() }
        .keyboardShortcut("f")
        .disabled(focusSearch == nil)
    }
    // View → destination navigation (⌘1/2/3), layout, completed toggle (⌘⇧C), Sort By.
    // The system Show/Hide Sidebar command (⌃⌘S) is restored automatically now that a
    // single NavigationSplitView sits at the window root, so no custom toggle is needed.
    CommandGroup(after: .sidebar) {
      Divider()
      Button {
        nav.showTimer()
      } label: {
        Label(AppLabels.Tab.timer.title, systemImage: nav.destination == .timer ? "checkmark" : "")
      }
      .keyboardShortcut("1")
      Button {
        nav.destination = .today
      } label: {
        Label(AppLabels.Tab.today.title, systemImage: nav.destination == .today ? "checkmark" : "")
      }
      .keyboardShortcut("2")
      Button {
        nav.showStats()
      } label: {
        Label(AppLabels.Tab.stats.title, systemImage: isStatsDestination ? "checkmark" : "")
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
      .disabled(!isTaskScope)
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
      .disabled(!isTaskScope)
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
