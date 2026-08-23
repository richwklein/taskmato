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
        nav: composition.nav,
        engine: composition.engine,
        registry: composition.registry,
        errorPresenter: composition.errorPresenter
      )
    } label: {
      HStack(spacing: 6) {
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
        destinationResolver: composition.destinationResolver,
        sidebarSelection: composition.sidebarSelection,
        nav: composition.nav,
        errorPresenter: composition.errorPresenter
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
              composition.urlHandler.pendingDisambiguation = nil
              composition.urlHandler.pendingAdHocParams = nil
              // On failure the handler surfaces the error on the banner and returns nil,
              // so no session is started on an unsaved task.
              if let task = await composition.urlHandler.makeAdHocTask(from: params) {
                composition.selectionStore.select(task)
                composition.nav.showTimerInMainWindow()
              }
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
    // A `MenuBarExtra` in the scene graph suppresses `Window` presentation at launch, so the
    // window-first shell asks for it explicitly (design doc 0008, D6 — launch surfaces the
    // window at its last destination).
    .defaultLaunchBehavior(.presented)
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

  @FocusedValue(\.taskViewActive) private var taskViewActive
  @FocusedValue(\.focusSearch) private var focusSearch
  @FocusedValue(\.addTask) private var addTask
  @FocusedValue(\.toggleCompleted) private var toggleCompleted
  @FocusedValue(\.toggleCompletedTitle) private var toggleCompletedTitle
  @FocusedValue(\.toggleCompletedIcon) private var toggleCompletedIcon
  @FocusedValue(\.trackTask) private var trackTask
  @FocusedValue(\.openInProvider) private var openInProvider
  @FocusedValue(\.openInProviderTitle) private var openInProviderTitle
  @FocusedValue(\.openInProviderIcon) private var openInProviderIcon
  @FocusedValue(\.timerToggle) private var timerToggle
  @FocusedValue(\.timerToggleTitle) private var timerToggleTitle
  @FocusedValue(\.timerSkip) private var timerSkip
  @FocusedValue(\.timerStop) private var timerStop
  @Environment(\.openURL) private var openURL

  /// The navigation model used to switch destinations from the View menu.
  var nav: MainNavigation
  /// App settings used to read and write layout and sort state for View menu checkmarks.
  @Bindable var settings: AppSettings
  /// The provider registry used to populate the File → Add Provider submenu.
  var registry: ProviderRegistry

  /// Whether the task surface currently owns the focused scene.
  ///
  /// Gates task-scope View menu commands (Layout, Sort By) on the presence of the
  /// ``FocusedValues/taskViewActive`` marker published by ``TaskDetailView``. Presence-based
  /// gating — the same mechanism Show/Hide Completed uses — grays these out reliably when the
  /// task surface leaves the scene, resolving #426 where value-comparison gating went stale.
  private var isTaskScope: Bool {
    taskViewActive == true
  }

  /// The sidebar toggle's title, reflecting the current column visibility.
  private var sidebarToggleTitle: String {
    nav.sidebarVisible ? AppLabels.View.hideSidebar.title : AppLabels.View.showSidebar.title
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
      Divider()
      // Track Task mirrors the Tasks-tab toolbar button and the row context menu. Return does
      // the same thing while the list has focus; ⌘T is the menu-reachable equivalent.
      Button {
        trackTask?()
      } label: {
        Label(AppLabels.Task.track.title, systemImage: AppLabels.Task.track.systemImage)
      }
      .keyboardShortcut("t")
      .disabled(trackTask == nil)
      // Title and glyph both come from the selected task's provider, so the item reads
      // "Open in Obsidian" beside Obsidian's own icon — matching its context-menu twin. Falls
      // back to the generic label when nothing resolvable is selected and the item is disabled.
      Button {
        openInProvider?()
      } label: {
        Label(
          openInProviderTitle ?? AppLabels.Task.openInProvider.title,
          systemImage: openInProviderIcon ?? AppLabels.Task.openInProvider.systemImage
        )
      }
      .keyboardShortcut("o", modifiers: [.command, .shift])
      .disabled(openInProvider == nil)
    }
    // Edit → Find… (⌘F); disabled when not on a task destination (focusSearch is only
    // published by the task detail surface).
    CommandGroup(after: .textEditing) {
      Divider()
      Button(AppLabels.View.find.title) { focusSearch?() }
        .keyboardShortcut("f")
        .disabled(focusSearch == nil)
    }
    // View → destination navigation (⌘1/2/3), layout, completed toggle (⌘⇧C), Sort By, and
    // the sidebar toggle (⌃⌘S) last so it sits just above the system Enter Full Screen item.
    // The main window drives column visibility with its own `nav.sidebarVisible` binding
    // (persisted to `UserDefaults`), which suppresses SwiftUI's automatic sidebar command, so
    // the toggle is provided explicitly here against that state.
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
      // Content shared with the toolbar's sort menu (``TaskSortMenuContent``) so field order,
      // defaults, and checkmarked state cannot drift between the two surfaces. Items are
      // disabled individually: as action items they re-validate on menu open and grey out live
      // off the task surface, whereas `.disabled` on the parent `Menu` container alone did not
      // update (see the Layout note above, #426).
      Menu {
        TaskSortMenuContent(settings: settings, disabled: !isTaskScope)
      } label: {
        Label(AppLabels.View.sort.title, systemImage: AppLabels.View.sort.systemImage)
      }
      .disabled(!isTaskScope)
      Divider()
      Button {
        nav.sidebarVisible.toggle()
      } label: {
        Label(sidebarToggleTitle, systemImage: AppLabels.View.showSidebar.systemImage)
      }
      .keyboardShortcut("s", modifiers: [.control, .command])
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
    // Help menu — links to the public support and privacy pages (App Store Guideline
    // 5.1.1(i) requires the privacy policy link both in ASC metadata and in the app).
    CommandGroup(replacing: .help) {
      Button(AppLabels.Help.support.title) { openURL(AppLinks.support) }
      Button(AppLabels.Help.privacyPolicy.title) { openURL(AppLinks.privacyPolicy) }
    }
  }
}
