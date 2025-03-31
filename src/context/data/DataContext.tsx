import { Project, TasksView } from '@types'
import { createContext } from 'react'

export interface DataContextType {
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
export const DataContext = createContext<DataContextType | undefined>(undefined)
