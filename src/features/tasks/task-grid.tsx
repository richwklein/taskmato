import { Grid } from '@mui/material'
import { Task } from '@types'

import TaskCard from './task-card'

interface TaskGridProps {
  tasks: Task[]
  sx?: object
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
export function TaskGrid({ tasks, sx }: TaskGridProps) {
  return (
    <Grid container spacing={1} sx={{ ...sx }}>
      {tasks.map((task) => {
        return (
          <Grid size={{ xl: 4, lg: 6, md: 12 }} key={task.id}>
            <TaskCard task={task} />
          </Grid>
        )
      })}
    </Grid>
  )
}

export default TaskGrid
