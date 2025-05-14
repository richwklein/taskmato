/**
 * Common type used to express the color on other objects
 *
 * @property id - The identifier of the color.
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
 * @property deadline - Optional date of when the task must be completed by.
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
  deadline: Date | null
  isCompleted: boolean
  parentId: string | null
  projectId: string
  sectionId: string | null
  order: number
  dayOrder: number
}

/**
 * Used to pass information between the sync service.
 *
 * @property token - the sync token used to indicate a partial sync
 * @property projects - The current or updated projects
 * @property sections - The current or updated sections
 * @property tasks - The current or updated tasks
 * @property labels - The current or updated labels
 */
export type SyncData = {
  token: string | null
  projects: Map<string, Project>
  sections: Map<string, Section>
  tasks: Map<string, Task>
  labels: Map<string, Label>
}

/**
 * The set of object that make up the data needed to populate the home's view of tasks.
 *
 * @property projectId - The currently selected project driving the view.
 * @property projects - The list of all possible projects to select.
 * @property sections - All the sections for the selected project.
 * @property tasks - All the tasks for the selected project.
 */
export type TasksView = {
  projectId: string | null
  sections: Section[]
  tasks: Task[]
}
