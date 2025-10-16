import AssignmentIcon from '@mui/icons-material/Assignment'
import type { SxProps, Theme } from '@mui/material/styles'
import { Priority } from '@types'

type PriorityIconProps = {
  priority: Priority
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * PriorityIcon Component
 *
 * The icon used to represent a task's priority.
 *
 * @param priority - The priority.
 * @param sx - The optional style object to apply.
 * @returns The rendered PriorityIcon component.
 */
export function PriorityIcon({ priority, sx }: PriorityIconProps) {
  return <AssignmentIcon sx={{ color: priority.color.hex, ...sx }} fontSize={'small'} />
}

export default PriorityIcon
