import { Project, Section, Task } from '@types'
import { createContext } from 'react'

/**
 * The data needed to drive the Tasks in the home view.
 * This includes a list of projects, the currently selected project,
 * and the sections and tasks within that project.
 */
export interface TasksView {
  projectId: string
  searchTerm?: string
  projects: Project[]
  sections: Section[]
  tasks: Task[]
}

/**
 * The context for the task provider.
 */
export interface TasksContextType {
  isInitialized: boolean
  isLoading: boolean
  view: TasksView | null
  sync: (force: boolean) => void
  showProject: (projectId: string) => void
  filterTasks: (searchTerm: string) => void
}

/**
 * The context for the task provider.
 *
 * @property isLoading - A boolean indicating if the tasks are currently loading.
 * @property isInitialized - A boolean indicating if the tasks have been initialized.
 * @property view - The data needed to drive the Tasks in the home view.
 * @property sync - A function to sync the tasks
 * @property showProject - select the project to show based on the given id.
 * @property filterTasks - filter the tasks based on the given search term.
 */
export const TasksContext = createContext<TasksContextType | undefined>(undefined)
