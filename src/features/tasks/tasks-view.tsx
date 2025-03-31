import { TasksToolbar } from '@features/tasks'
import { useDataContext } from '@hooks/useDataContext'
import { Box } from '@mui/material'

/**
 * TasksView component
 *
 * This home view component is the element for the index route.
 * It displays the list of tasks and let's you start a Pomodoro session.
 *
 * @returns the rendered Home component.
 */
export function TasksView() {
  const { view } = useDataContext()
  if (!view) {
    return null
  }

  return (
    <Box component={'main'} sx={{ px: 2 }}>
      <TasksToolbar sx={{ mb: 2 }} />
    </Box>
  )
}

export default TasksView
