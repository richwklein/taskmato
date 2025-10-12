import { Card, CardHeader } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { Task } from '@types'
import { MuiMarkdown } from 'mui-markdown'

import PriorityIcon from './priority-icon'

interface TaskCardProps {
  task: Task
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * TaskCard Component
 *
 * A component for rendering a single task card.
 *
 * @param task - The task to render.
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered TaskCard component.
 */
export function TaskCard({ task, sx }: TaskCardProps) {
  return (
    <Card variant={'outlined'} sx={{ ...sx }}>
      <CardHeader
        avatar={<PriorityIcon priority={task.priority} />}
        title={<MuiMarkdown>{task.content}</MuiMarkdown>}
        subheader={task.due?.toLocaleString('en-US')} // TODO fix timezone and now time cases
      />
    </Card>
  )
}

export default TaskCard
