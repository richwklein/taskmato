import { TasksContext, TasksContextType, TasksView } from '@features/tasks/tasks-context'
import tasksService from '@features/tasks/tasks-service'
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
  const [view, setView] = useState<TasksView>({
    projectId: DEFAULT_PROJECT_ID,
    projects: [],
    sections: [],
    tasks: [],
  })

  const syncView = useCallback(
    async (projectId: string, searchTerm: string | undefined) => {
      const project = await tasksService.getProjectById(projectId)
      const setId = project ? project.id : DEFAULT_PROJECT_ID
      console.log(`projectId=${projectId}, setId=${setId}, searchTerm=${searchTerm}`)

      // filter tasks and sections
      let sections = await tasksService.getSectionsByProjectId(setId)
      let tasks = await tasksService.getTasksByProjectId(setId)
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
        projects: await tasksService.getProjects(),
        sections: sections,
        tasks: tasks,
      }
    },
    [tasksService]
  )

  const sync = useCallback(
    async (force: boolean) => {
      setLoading(true)

      try {
        const results = await tasksService.sync(force)
        if (results.status === 'error') {
          throw new Error(results.message)
        }

        if (!isInitialized) {
          setInitialized(true)
        }

        setView(await syncView(view.projectId, view.searchTerm))
        console.log(view)
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

  const contextValue: TasksContextType = {
    isInitialized,
    isLoading,
    view,
    sync,
    showProject,
    filterTasks,
  }

  return <TasksContext.Provider value={contextValue}>{children}</TasksContext.Provider>
}

export default TasksProvider
