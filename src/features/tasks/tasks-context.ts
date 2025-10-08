import { Project, Section, Task } from '@types'
import { createContext } from 'react'

/**
 * The data needed to drive the Tasks in the home view.
 * This includes a list of projects, the currently selected project,
 * and the sections and tasks within that project.
 */
export interface TasksView {
  projectId: string
  sections: Section[]
  tasks: Task[]
}

/**
 * The context for the task provider.
 */
export interface TasksContextType {
  isLoading: boolean
  projects: Project[]
  view: TasksView | null
  sync: (force: boolean) => void
  showProject: (projectId: string) => void
}

/**
 * The context for the task provider.
 *
 * @property isLoading - A boolean indicating if the tasks are currently loading.
 * @property projects - The projects that the tasks are organized into.
 * @property view - The data needed to drive the Tasks in the home view.
 * @property sync - A function to sync the tasks
 * @property showProject - select the project to show based on the given id.
 */
export const TasksContext = createContext<TasksContextType | undefined>(undefined)
