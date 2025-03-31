import AssignmentIcon from '@mui/icons-material/Assignment'
import { Priority } from '@types'

type PriorityFlagProps = {
  priority: Priority
}

/**
 * PriorityIcon Component
 *
 * The icon used to represent a task's priority.
 *
 * @param id - The priority flag id.
 * @returns The rendered PriorityIcon component.
 */
export function PriorityIcon({ priority }: PriorityFlagProps) {
  return <AssignmentIcon sx={{ color: priority.color.hex }} />
}

export default PriorityIcon
