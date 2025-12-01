import { TasksContext } from '@features/tasks/tasks-context'
import { useContext } from 'react'

/**
 * useTasksContext Hook.
 *
 * Hook for getting the {TasksContext} context.
 *
 * @returns the TasksContext context.
 * @throws an exception if not called within the DataProvider component.
 */
export function useTasksContext() {
  const context = useContext(TasksContext)
  if (!context) {
    throw new Error('useTasksContext must be used within a TaskProvider')
  }
  return context
}

export default useTasksContext
