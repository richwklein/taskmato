import useTasksContext from '@features/tasks/use-tasks'
import RefreshIcon from '@mui/icons-material/Refresh'
import { CircularProgress, IconButton } from '@mui/material'

type RefreshButtonProps = {
  sx?: object
}

/**
 * RefreshButton Component
 *
 * The button used to refresh the tasks for the home view.
 *
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered RefreshComponent
 */
export function RefreshButton({ sx }: RefreshButtonProps) {
  const { isLoading, sync } = useTasksContext()

  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    if (event.shiftKey) {
      sync(true)
    } else {
      sync(false)
    }
  }

  return (
    <IconButton
      aria-label="Refresh"
      color="inherit"
      onClick={handleClick}
      disabled={isLoading}
      sx={{ ...sx }}
    >
      {isLoading ? <CircularProgress color="inherit" size={24} /> : <RefreshIcon />}
    </IconButton>
  )
}

export default RefreshButton
