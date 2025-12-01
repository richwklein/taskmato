/**
 * Common type used to express the color on other objects
 */
export type Color = {
  /** The lowercase identifier of the color. */
  id: string
  /** The readable display name. */
  name: string
  /** The hexadecimal color value. */
  hex: string
}

/**
 * The priority of tasks where the id is the order descending.
 */
export type Priority = {
  /** The identifier of the priority. */
  id: number
  /** The readable display name. */
  name: string
  /** The assigned color of the priority. */
  color: Color
}

/**
 * The type of the project. Today and inbox projects are treated specially.
 */
export const PROJECT_TYPE = {
  Today: 'today',
  Inbox: 'inbox',
  Project: 'project',
} as const

export type ProjectType = (typeof PROJECT_TYPE)[keyof typeof PROJECT_TYPE]

/**
 * A project that tasks are organized into.
 */
export type Project = {
  /** The identifier of the project. */
  id: string
  /** The readable display name. */
  name: string
  /** The assigned color of the priority. */
  color: Color
  /** The type of project. This is to identify special types. */
  type: ProjectType
  /** Id of the parent project this project belongs under. */
  parentId: string | null
  /** Sort order of projects within a parent. */
  order: number
}

/**
 * The section underneath a project that a task is in.
 */
export interface Section {
  /** The identifier of the section. */
  id: string
  /** The name of the section. */
  name: string
  /** The identifier of the project the section belongs to. */
  projectId: string
  /** The sort order of the sections within the project. */
  order: number
}

/**
 * A label that can be placed on a task.
 */
export type Label = {
  /** The identifier of the project. */
  id: string
  /** The readable display name. */
  name: string
  /** The assigned color of the priority. */
  color: Color
  /** The sort order of the labels. */
  order: number
}

/**
 * The task that needs to be completed.
 */
export type Task = {
  /** The identifier of the task. */
  id: string
  /** The priority of the task. */
  priority: Priority
  /** Markdown content. */
  content: string
  /** A long Markdown description. */
  description: string
  /** A list of labels associated with the task. */
  labels: Label[]
  /** Optional due date when this should be completed. */
  due: Date | null
  /** If the work has been marked as completed. */
  isCompleted: boolean
  /** Optional parent task of this work. */
  parentId: string | null
  /** The project the task belongs to (today project is special). */
  projectId: string
  /** Optional section the task is in (treated special when null or today). */
  sectionId: string | null
  /** Order of the task within it's parent, section, and project. */
  order: number
  /** The order to sort the task in the today view. */
  dayOrder: number
}

/** Possible setting value types that can be stored in the database. */
export type SettingsType = string | number | boolean | null

/** The representation of a setting for storage. */
export type Setting = {
  /** The unique key of the setting. */
  key: string
  /** The value of the setting which can be a string, number, or boolean. */
  value: SettingsType
}

/** Session phases for a Pomodoro cycle. */
export type SessionPhase = 'focus' | 'short-break' | 'long-break'

/**
 * Segment snapshot of a timer session (focus or break).
 * Saved when a segment ends and later used to build task totals and statistics.
 */
export interface SessionSnapshot {
  /** Primary key for storage of the record. */
  id?: number
  /** Task id the segment belongs to. */
  taskId: string
  /** Phase type (focus/break). */
  phase: SessionPhase
  /** Milliseconds spent during the segment. */
  duration: number
  /** Timestamp when the segment started. */
  startTime: number
  /** Optional label name snapshot at time of session. */
  labels?: string[]
}
