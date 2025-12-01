import { TasksContext, TasksContextType, TasksView } from '@features/tasks/tasks-context'
import { useCallback, useEffect, useMemo, useState } from 'react'

import { TasksService } from '../services/TasksService'

const DEFAULT_PROJECT_ID: string = 'today'

export interface TasksProviderProps {
  /** TasksService instance to fetch task information from. */
  service: TasksService

  /** React children to be wrapped by the provider. */
  children: React.ReactNode
}

/**
 * TaskProvider Component
 */
export function TasksProvider({ service, children }: TasksProviderProps) {
  const [isLoading, setLoading] = useState<boolean>(false)
  const [isInitialized, setInitialized] = useState<boolean>(false)
  const [view, setView] = useState<TasksView>({
    projectId: DEFAULT_PROJECT_ID,
    projects: [],
    sections: [],
    tasks: [],
  })

  const syncView = useCallback(
    async (projectId: string, searchTerm: string | undefined) => {
      const project = await service.getProjectById(projectId)
      const setId = project ? project.id : DEFAULT_PROJECT_ID

      // filter tasks and sections
      let sections = await service.getSectionsByProjectId(setId)
      let tasks = await service.getTasksByProjectId(setId)
      if (searchTerm) {
        tasks = tasks.filter((task) =>
          task.content.toLowerCase().includes(searchTerm.toLowerCase())
        )

        const sectionIdsWithTasks = new Set(tasks.map((task) => task.sectionId))
        sections = sections.filter((section) => sectionIdsWithTasks.has(section.id))
      }

      return {
        projectId: setId,
        searchTerm: searchTerm,
        projects: await service.getProjects(),
        sections: sections,
        tasks: tasks,
      }
    },
    [service]
  )

  const sync = useCallback(
    async (force: boolean) => {
      setLoading(true)

      try {
        const results = await service.sync(force)
        if (results.status === 'error') {
          setInitialized(false)
        }

        if (!isInitialized) {
          setInitialized(true)
        }

        setView(await syncView(view.projectId, view.searchTerm))
      } catch (error) {
        console.error('Failed to load tasks', error)
        throw error
      } finally {
        setLoading(false)
      }
    },
    [view, isInitialized, syncView]
  )

  const showProject = useCallback(
    async (projectId: string) => {
      setView(await syncView(projectId, view.searchTerm))
    },
    [view, syncView]
  )

  const filterTasks = useCallback(
    async (searchTerm: string) => {
      setView(await syncView(view.projectId, searchTerm))
    },
    [view, syncView]
  )

  useEffect(() => {
    if (!isInitialized) {
      sync(false)
    }
  }, [isInitialized, sync])

  const contextValue = useMemo<TasksContextType>(
    () => ({
      isInitialized,
      isLoading,
      view,
      sync,
      showProject,
      filterTasks,
    }),
    [isInitialized, isLoading, view, sync, showProject, filterTasks]
  )

  return <TasksContext.Provider value={contextValue}>{children}</TasksContext.Provider>
}

export default TasksProvider
