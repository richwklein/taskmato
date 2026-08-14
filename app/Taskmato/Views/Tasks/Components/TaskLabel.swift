//
//  TaskLabel.swift
//  Taskmato
//

/// A paired title and SF Symbol name used consistently across menus, toolbars, and buttons.
struct AppLabel {
  /// Title-style string for menus and toolbar labels.
  let title: String
  /// SF Symbol name for the accompanying icon.
  let systemImage: String

  init(_ title: String, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }
}

/// String constants and icon pairings for all app-level UI labels.
///
/// `Tooltip` entries use sentence-style capitalization per the macOS HIG.
/// All other entries use title-style capitalization per the macOS HIG.
enum AppLabels {

  /// Tooltip strings for action buttons — sentence-style capitalization.
  enum Tooltip {
    // Task item state buttons
    /// Shown on the completion circle when no session is running.
    static let markAsCompleted = "Mark as completed"
    /// Shown on the completion circle when a timer session is active.
    static let markAsCompletedActive = "Mark as completed (will pause timer)"
    /// Shown on the restore circle of a completed task row or card.
    static let restore = "Restore task"
    /// Shown on the trash button of a completed task row or card.
    static let deletePermanently = "Delete permanently"
    // Active task row
    /// Shown on the swap button when a session is active.
    static let swapTask = "Swap task — pauses the session and opens the task list"
    /// Shown on the clear button in the active task row.
    static let clearTask = "Clear task"
    /// Shown on the cancel button in an inline confirmation row.
    static let cancel = "Cancel"
    // Timer controls
    /// Shown on the Start button when no task is selected.
    static let selectTaskFirst = "Select a task before starting"
    // Tasks toolbar
    /// Shown on the Add Task toolbar button.
    static let addTask = "Add a task"
    /// Shown on the Show Completed toolbar button when the section is hidden.
    static let showCompleted = "Show completed tasks"
    /// Shown on the Show Completed toolbar button when the section is visible.
    static let hideCompleted = "Hide completed tasks"
    // Focus presets
    /// Shown on "Add Duration" once the Focus presets list already holds 5 entries.
    static let maxFocusPresetsReached = "Up to 5 focus presets"
  }

  /// VoiceOver labels for controls whose visible content is not text.
  enum Accessibility {
    /// Announced for the circular countdown ring on the Timer surface.
    static let timer = "Pomodoro timer"
    /// Announced for the Timer tab's focus-length quick-select chip row.
    static let focusPresets = "Focus duration"
    /// Announced for the Stats daily focus stacked bar chart.
    static let dailyFocusChart = "Daily focus chart"
    /// Announced for the Stats task breakdown donut chart.
    static let taskBreakdownChart = "Task breakdown chart"
  }

  /// Labels for task CRUD and lifecycle actions.
  enum Task {
    /// Sets the task as active and switches to the Timer tab.
    static let track = AppLabel("Track Task", systemImage: "timer")
    /// Opens the Add Task sheet.
    static let add = AppLabel("New Task", systemImage: "plus")
    /// Opens the Edit Task sheet.
    static let edit = AppLabel("Edit Task…", systemImage: "pencil")
    /// Marks the task as completed via its closable provider.
    static let complete = AppLabel("Mark as Completed", systemImage: "checkmark.circle.fill")
    /// Restores a completed task to the active list.
    static let restore = AppLabel("Restore Task", systemImage: "arrow.counterclockwise")
    /// Permanently deletes a task via its writable provider.
    static let delete = AppLabel("Delete Permanently", systemImage: "trash")
    /// Copies a task to the clipboard as a Taskmato payload and plain-text title.
    static let copy = AppLabel("Copy", systemImage: "doc.on.doc")
    /// Copies a task to the clipboard, then deletes it from its writable provider.
    static let cut = AppLabel("Cut", systemImage: "scissors")
    /// Greyed-out File-menu placeholder shown when no resolvable task is selected; every
    /// enabled instance instead uses ``TaskProviderLink/title`` to name the provider.
    static let openInProvider = AppLabel("Open in Provider", systemImage: "arrow.up.forward.app")
  }

  /// Labels for the focus-duration presets feature (design doc 0009): the Settings editor,
  /// the timer quick-select surfaces, and the task "Start Focus" submenu.
  enum FocusPreset {
    /// Section label for the presets editor in Settings → Durations.
    static let sectionTitle = "Focus Presets"
    /// Suffix appended to the preset row matching the current `focusMinutes`.
    static let current = "Current"
    /// Removes a preset from the list in Settings.
    static let remove = AppLabel("Remove", systemImage: "minus.circle")
    /// Reveals the inline control to add a new preset in Settings.
    static let add = AppLabel("Add Duration", systemImage: "plus.circle")
    /// The task context-menu submenu offering a one-click "select + start" at a preset length.
    static let startFocus = AppLabel("Start Focus", systemImage: "bolt.fill")
  }

  /// Copy for the Obsidian file-pattern date-token help disclosure (issue #510).
  enum ObsidianTokens {
    /// Label for the collapsed disclosure row above the File patterns field.
    static let disclosureLabel = "Using date tokens in file patterns"
    /// Intro sentence shown when the disclosure is expanded.
    static let intro = "File patterns support date tokens that expand to today's date:"
    /// Describes the {year} / {YYYY} token pair.
    static let yearToken = "{year} or {YYYY}: 4-digit year, e.g. 2026"
    /// Describes the {month} / {MM} token pair.
    static let monthToken = "{month} or {MM}: zero-padded month, e.g. 08"
    /// Describes the {week} / {ww} token pair.
    static let weekToken = "{week} or {ww}: ISO week number, e.g. 32"
    /// Describes the {day} / {DD} token pair.
    static let dayToken = "{day} or {DD}: zero-padded day of month, e.g. 03"
    /// Example pattern shown at the end of the disclosure.
    static let example = "Example: journal/{year}/{month}-{day}.md"
  }

  /// Labels for view-state commands: layout, completed section, sort, and search.
  enum View {
    /// Focuses the search field.
    static let find = AppLabel("Find…", systemImage: "magnifyingglass")
    /// Shows the completed tasks section.
    static let showCompleted = AppLabel("Show Completed", systemImage: "eye")
    /// Hides the completed tasks section.
    static let hideCompleted = AppLabel("Hide Completed", systemImage: "eye.slash")
    /// Switches the task picker to list layout.
    static let listLayout = AppLabel("as List", systemImage: "list.bullet")
    /// Switches the task picker to grid layout.
    static let gridLayout = AppLabel("as Grid", systemImage: "square.grid.2x2")
    /// The sort toolbar menu.
    static let sort = AppLabel("Sort", systemImage: "arrow.up.arrow.down")
    /// Opens the task browser from the timer views.
    static let browseTask = AppLabel("Browse Tasks…", systemImage: "list.bullet")
    /// Shows the provider sidebar column.
    static let showSidebar = AppLabel("Show Sidebar", systemImage: "sidebar.left")
    /// Hides the provider sidebar column.
    static let hideSidebar = AppLabel("Hide Sidebar", systemImage: "sidebar.left")
  }

  /// Labels for timer session controls.
  enum Timer {
    /// Starts a new focus session.
    static let start = AppLabel("Start", systemImage: "play.fill")
    /// Pauses the running session.
    static let pause = AppLabel("Pause", systemImage: "pause.fill")
    /// Resumes a paused session.
    static let resume = AppLabel("Resume", systemImage: "play.fill")
    /// Skips the current phase and advances to the next.
    static let skip = AppLabel("Skip Phase", systemImage: "forward.fill")
    /// Stops the current session.
    static let stop = AppLabel("Stop", systemImage: "stop.fill")
  }

  /// Labels for the Help menu's in-app links (App Store Guideline 5.1.1(i)).
  enum Help {
    /// Opens the public support page in the default browser.
    static let support = AppLabel("Taskmato Support", systemImage: "questionmark.circle")
    /// Opens the public privacy policy in the default browser.
    static let privacyPolicy = AppLabel("Privacy Policy", systemImage: "hand.raised")
  }

  /// Labels for the primary window destinations.
  enum Tab {
    static let tasks = AppLabel("Tasks", systemImage: "checklist")
    static let today = AppLabel("Today", systemImage: "calendar")
    static let timer = AppLabel("Timer", systemImage: "timer")
    static let stats = AppLabel("Stats", systemImage: "chart.bar")
  }

  /// Banner titles for failed user-initiated provider operations — sentence-style
  /// capitalization; the failing error's `localizedDescription` supplies the detail.
  enum Error {
    /// A task could not be marked completed.
    static let completeFailed = "Couldn't complete task"
    /// A completed task could not be restored.
    static let restoreFailed = "Couldn't restore task"
    /// A task could not be deleted.
    static let deleteFailed = "Couldn't delete task"
    /// A new task could not be added.
    static let addFailed = "Couldn't add task"
    /// An edited task could not be saved.
    static let updateFailed = "Couldn't save task"
    /// A new list could not be created.
    static let listCreateFailed = "Couldn't create list"
    /// A list could not be renamed.
    static let listRenameFailed = "Couldn't rename list"
    /// A list could not be deleted.
    static let listDeleteFailed = "Couldn't delete list"
    /// A list could not be set as the provider default.
    static let setDefaultFailed = "Couldn't set default list"
    /// An ad-hoc task from a `taskmato://` link could not be created.
    static let adhocCreateFailed = "Couldn't create task"
    /// The active task vanished from its provider mid-focus — deleted, completed elsewhere, or
    /// its provider temporarily unreadable; these all look identical from here (issue #547).
    static func taskNotAvailable(title: String) -> String {
      "\u{201C}\(title)\u{201D} is not available"
    }
  }

  /// Labels for provider sidebar actions.
  enum Sidebar {
    /// Opens the Add Task sheet targeted at a specific list.
    static let addTask = AppLabel("Add Task…", systemImage: "plus.circle")
    /// Marks a list as the default for its provider.
    static let setDefault = AppLabel("Set as Default", systemImage: "star")
    /// Begins an inline rename of the selected list.
    static let rename = AppLabel("Rename", systemImage: "pencil")
    /// Deletes the selected list from its provider.
    static let deleteList = AppLabel("Delete", systemImage: "trash")
    /// Opens the provider configuration sheet.
    static let configure = AppLabel("Configure…", systemImage: "gear")
    /// Disables and removes the provider from the sidebar.
    static let remove = AppLabel("Remove", systemImage: "trash")
    /// Opens the Add Provider menu at the sidebar bottom.
    static let addProvider = AppLabel("Add Provider", systemImage: "plus.circle")
  }
}
