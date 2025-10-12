import { LoadingBar } from '@components/common'
import { BoardToolbar } from '@components/tasks'
import { useTasksContext } from '@features/tasks/use-tasks'
import { Box } from '@mui/material'

import { TasksSections } from './task-sections'

/**
 * TasksView component
 *
 * This home view component is the element for the index route.
 * It displays the list of tasks and let's you start a Pomodoro session.
 *
 * @returns the rendered Home component.
 */
export function TasksView() {
  const { isLoading, isInitialized, view } = useTasksContext()

  return (
    <Box component={'main'} sx={{ mt: 0 }}>
      <LoadingBar isLoading={!isInitialized || isLoading} sx={{ mb: 2 }} />
      <Box sx={{ px: 2 }}>
        <BoardToolbar sx={{ mb: 2 }} />
        <TasksSections sections={view?.sections || []} tasks={view?.tasks || []} />
      </Box>
    </Box>
  )
}

export default TasksView
