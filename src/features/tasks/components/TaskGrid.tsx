import { TaskCard } from '@components/tasks'
import { Grid } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { Task } from '@types'

interface TaskGridProps {
  tasks: Task[]
  onStartTask: (task: Task) => void
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * TaskGrid Component
 *
 * A component for rendering a grid of tasks in the home view.
 *
 * @param tasks - The list of tasks to render in order.
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered TaskGrid component.
 */
export function TaskGrid({ tasks, onStartTask, sx }: TaskGridProps) {
  return (
    <Grid container spacing={1} sx={{ ...sx }}>
      {tasks.map((task) => {
        return (
          <Grid size={{ xl: 4, lg: 6, md: 12 }} key={task.id} alignItems={'stretch'}>
            <TaskCard task={task} onStartTask={onStartTask} />
          </Grid>
        )
      })}
    </Grid>
  )
}

export default TaskGrid
