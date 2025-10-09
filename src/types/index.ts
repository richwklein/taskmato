/**
 * Common type used to express the color on other objects
 *
 * @property id - The lowercase identifier of the color.
 * @property name - The readable display name.
 * @property hex - The hexadecimal color value.
 */
export type Color = {
  id: string
  name: string
  hex: string
}

/**
 * The priority of tasks where the id is the order descending.
 *
 * @property id - The identifier of the priority.
 * @property name - The readable display name.
 * @property color - The assigned color of the priority.
 */
export type Priority = {
  id: number
  name: string
  color: Color
}

/**
 * The type of the project. Today and Inbox projects are treated specially.
 */
export enum ProjectType {
  Today = 0,
  Inbox = 1,
  Project = 2,
}

/**
 * A project that tasks are organized into.
 *
 * @property id - The identifier of the project.
 * @property name - The readable display name.
 * @property color - The assigned color of the priority.
 * @property type - The type of project. This is to identify special types.
 * @property parentId - Id of the parent project this project belongs under.
 * @property order - sort order of projects within a parent.
 * @property indent - Indentation level based on depth of parent.
 */
export type Project = {
  id: string
  name: string
  color: Color
  type: ProjectType
  parentId: string | null
  order: number
}

/**
 * The section underneath a project that a task is in.
 *
 * @property id - The identifier of the section.
 * @property name - The name of the section.
 * @property projectId - The identifier of the section
 * @property order - The sort order of the sections within the project.
 */
export interface Section {
  id: string
  name: string
  projectId: string
  order: number
}

/**
 * A label that can be placed on a task.
 *
 * @property id - The identifier of the project.
 * @property name - The readable display name.
 * @property color - The assigned color of the priority.
 * @property order - The sort order of the labels.
 */
export type Label = {
  id: string
  name: string
  color: Color
  order: number
}

/**
 * The task that needs to be completed.
 *
 * @property id - The identifier of the task.
 * @property priority - The priority of the task.
 * @property content - Markdown content.
 * @property description - A long Markdown description.
 * @property labels - A list of labels associated with the task.
 * @property due - Optional due date when this should be completed.
 * @property isCompleted - If the work has been marked as completed.
 * @property parentId - Optional parent task of this work.
 * @property projectId - The project the task belongs to (today project is special).
 * @property sectionId - The optional section the task is in (treated special when null or today).
 * @property order - Order of the task within it's parent, section, and project.
 * @property dayOrder - The order to sort the task in the today view.
 */
export type Task = {
  id: string
  priority: Priority
  content: string
  description: string
  labels: Label[]
  due: Date | null
  isCompleted: boolean
  parentId: string | null
  projectId: string
  sectionId: string | null
  order: number
  dayOrder: number
}

/**
 * A setting stored in the database.
 * @property key - The unique key of the setting.
 * @property value - The value of the setting which can be a string, number, or boolean.
 */
export type Setting = {
  key: string
  value: string | number | boolean
}
