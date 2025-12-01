import { useCallback } from 'react'

import { useTasksContext } from './useTasksContext'

/** Small hook to sync tasks */
export function useSyncTasks() {
  const { sync } = useTasksContext()
  return useCallback((force: boolean) => sync(force), [sync])
}
