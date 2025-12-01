import MoreVertIcon from '@mui/icons-material/MoreVert'
import {
  Button,
  Card,
  CardActions,
  CardContent,
  CardHeader,
  IconButton,
  Tooltip,
  Typography,
  useTheme,
} from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { Task } from '@types'
import { MuiMarkdown } from 'mui-markdown'

import PriorityIcon from '../../features/tasks/priority-icon'
interface TaskCardProps {
  task: Task
  onStartTask: (task: Task) => void
  sx?: SxProps<Theme>
}

export function TaskCard({ task, onStartTask, sx }: TaskCardProps) {
  const theme = useTheme()

  const dueDate = task.due ? new Date(task.due) : null
  const now = new Date()
  const isOverdue = dueDate ? dueDate < now && !isSameDay(dueDate, now) : false

  // Detect if time is meaningful (non-midnight)
  const hasTime =
    dueDate &&
    (dueDate.getHours() !== 0 || dueDate.getMinutes() !== 0 || dueDate.getSeconds() !== 0)

  // Localized formatting for tooltip
  const formattedDue = dueDate
    ? dueDate.toLocaleDateString(undefined, {
        month: 'short',
        day: 'numeric',
        ...(hasTime && { hour: 'numeric', minute: '2-digit' }),
      })
    : null

  // Tooltip message (colored when overdue)
  const dueTooltip = formattedDue
    ? `${isOverdue ? 'Overdue ' : 'Due '}${formattedDue}`
    : 'No due date'

  return (
    <Card
      variant="outlined"
      sx={{
        display: 'flex',
        flexDirection: 'row',
        alignItems: 'flex-start',
        ...sx,
      }}
    >
      {/* Left: Priority icon with due date tooltip */}
      <CardHeader
        avatar={
          <Tooltip
            title={
              <Typography
                variant="caption"
                sx={{
                  color: isOverdue ? theme.palette.error.main : theme.palette.text.primary,
                }}
              >
                {dueTooltip}
              </Typography>
            }
            placement="top"
          >
            <span>
              <PriorityIcon priority={task.priority} />
            </span>
          </Tooltip>
        }
        sx={{
          flex: '0 0 auto',
          p: 1,
          alignSelf: 'flex-start',
          '.MuiCardHeader-avatar': { m: 0 },
        }}
      />

      {/* Middle: Expanding markdown content */}
      <CardContent
        sx={{
          flex: 1,
          minWidth: 0,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'flex-start',
          py: 1,
          '&:last-child': { pb: 1 },
        }}
      >
        <Typography
          component="div"
          variant="body2"
          sx={{
            '& p, & ul, & ol': { margin: 0 },
          }}
        >
          <MuiMarkdown>{task.content}</MuiMarkdown>
        </Typography>
      </CardContent>

      {/* Right: Inline actions */}
      <CardActions
        disableSpacing
        sx={{
          flex: '0 0 auto',
          display: 'flex',
          flexDirection: 'row',
          alignItems: 'flex-start',
          justifyContent: 'flex-end',
          gap: 1,
          p: 1,
        }}
      >
        <Tooltip title="Start Pomodoro">
          <Button
            size="small"
            variant="contained"
            color="primary"
            onClick={() => onStartTask(task)}
            sx={{
              textTransform: 'none',
              fontSize: 12,
              px: 1.5,
              py: 0.25,
            }}
          >
            Start
          </Button>
        </Tooltip>

        <IconButton size="small">
          <MoreVertIcon fontSize="small" />
        </IconButton>
      </CardActions>
    </Card>
  )
}

/** Utility: same calendar day check */
function isSameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  )
}

export default TaskCard
