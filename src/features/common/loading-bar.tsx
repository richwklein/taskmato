import useTasksContext from '@features/tasks/use-tasks'
import { Box, LinearProgress } from '@mui/material'

type LoadingBarProps = {
  sx?: object
}

/**
 * LoadingBar Component
 *
 * A undetermined loading bar that displays when tasks are being loaded.
 *
 * @param sx - The optional style object to apply to the loading bar.
 * @returns The rendered LoadingBar component.
 */
export function LoadingBar({ sx }: LoadingBarProps) {
  /** TODO see if we can pass in the loading state */
  const { isLoading } = useTasksContext()

  if (isLoading) {
    return <LinearProgress sx={{ ...sx }} />
  }

  return <Box sx={{ height: 4, ...sx }} />
}

export default LoadingBar
