import { DataContext, DataContextType } from '@context/data/DataContext'
import SyncService from '@services/SyncService'
import { Project, SyncData, TasksView } from '@types'
import {
  defaultProjectId,
  getProjects,
  getSectionsByProjectId,
  getTasksByProjectId,
} from '@utils/data'
import React, { useCallback, useEffect, useState } from 'react'

/**
 * DataProvider Component
 *
 * Provider for the {DataContext} used to supply functionality.
 *
 * @param children - The children this component wraps.
 * @returns the rendered DataProvider component.
 */
export const DataProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isLoading, setLoading] = useState<boolean>(false)
  const [isInitialized, setInitialized] = useState<boolean>(false)
  const [projects, setProjects] = useState<Project[]>([])
  const [view, setView] = useState<TasksView | null>(null)
  const [syncData, setSyncData] = useState<SyncData>({
    token: null,
    projects: new Map(),
    sections: new Map(),
    tasks: new Map(),
    labels: new Map(),
  })

  const cleanData = useCallback(() => {
    return {
      token: null,
      projects: new Map(),
      sections: new Map(),
      tasks: new Map(),
      labels: new Map(),
    }
  }, [])

  const createView = useCallback(
    (projectId: string, data: SyncData) => {
      const project = projects.find((project) => project.id === projectId)
      const setId = project ? project.id : defaultProjectId
      return {
        projectId: setId,
        sections: getSectionsByProjectId(setId, data.sections),
        tasks: getTasksByProjectId(setId, data.tasks),
      }
    },
    [projects]
  )

  const showProject = useCallback(
    (projectId: string) => {
      setView(createView(projectId, syncData))
    },
    [createView, syncData]
  )

  const sync = useCallback(
    async (force: boolean) => {
      // use new data if forcing a refresh
      const data = !force ? syncData : cleanData()

      setLoading(true)
      try {
        const newData = await SyncService.sync(data)
        setSyncData(newData)

        // Merge the stored data and the synced data
        setProjects(getProjects(newData.projects))

        if (!isInitialized) {
          setInitialized(true)
          setView(createView(defaultProjectId, newData))
        }
      } catch (error) {
        console.error('Failed to load tasks', error)
        throw error
      } finally {
        setLoading(false)
      }
    },
    [isInitialized, syncData, cleanData, createView]
  )

  useEffect(() => {
    if (!isInitialized) {
      sync(true)
    }
  }, [isInitialized, sync])

  const contextValue: DataContextType = {
    isLoading,
    projects,
    view,
    sync,
    showProject,
  }

  return <DataContext.Provider value={contextValue}>{children}</DataContext.Provider>
}

export default DataProvider
