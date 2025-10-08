import { TasksContext, TasksContextType, TasksView } from '@features/tasks/tasks-context'
import tasksService from '@features/tasks/tasks-service'
import { Project } from '@types'
import React, { useCallback, useEffect, useState } from 'react'

/** Id of the project that is selected by default */
export const DEFAULT_PROJECT_ID: string = 'today'

/**
 * TaskProvider Component
 *
 * Provider for the {TasksContext} used to supply functionality.
 *
 * @param children - The children this component wraps.
 * @returns the rendered TaskProvider component.
 */
export const TasksProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isLoading, setLoading] = useState<boolean>(false)
  const [isInitialized, setInitialized] = useState<boolean>(false)
  const [view, setView] = useState<TasksView | null>(null)
  const [projects, setProjects] = useState<Project[]>([])

  const createView = useCallback(
    async (projectId: string) => {
      const project = projects.find((project) => project.id === projectId)
      const setId = project ? project.id : DEFAULT_PROJECT_ID
      return {
        projectId: setId,
        sections: await tasksService.getSectionsByProjectId(setId),
        tasks: await tasksService.getTasksByProjectId(setId),
      }
    },
    [projects]
  )

  const showProject = useCallback(
    async (projectId: string) => {
      setView(await createView(projectId))
    },
    [createView]
  )

  const sync = useCallback(
    async (force: boolean) => {
      setLoading(true)

      try {
        const results = await tasksService.sync(force)
        if (results.status === 'error') {
          throw new Error(results.message)
        }

        setProjects(await tasksService.getProjects())
        if (!isInitialized) {
          setInitialized(true)
          setView(await createView(DEFAULT_PROJECT_ID))
        }
      } catch (error) {
        console.error('Failed to load tasks', error)
        throw error
      } finally {
        setLoading(false)
      }
    },
    [isInitialized, createView]
  )

  useEffect(() => {
    if (!isInitialized) {
      sync(false)
    }
  }, [isInitialized, sync])

  const contextValue: TasksContextType = {
    isLoading,
    projects,
    view,
    sync,
    showProject,
  }

  return <TasksContext.Provider value={contextValue}>{children}</TasksContext.Provider>
}

export default TasksProvider
