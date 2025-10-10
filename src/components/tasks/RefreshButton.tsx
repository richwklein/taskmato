import RefreshIcon from '@mui/icons-material/Refresh'
import { IconButton } from '@mui/material'

type RefreshButtonProps = {
  disabled: boolean
  onRefresh: () => void
  onHardRefresh: () => void
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
export function RefreshButton({ disabled, onRefresh, onHardRefresh, sx }: RefreshButtonProps) {
  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    if (event.shiftKey) {
      onHardRefresh()
    } else {
      onRefresh()
    }
  }

  return (
    <IconButton
      aria-label="Refresh"
      color="inherit"
      onClick={handleClick}
      disabled={disabled}
      sx={{ ...sx }}
    >
      <RefreshIcon />
    </IconButton>
  )
}

export default RefreshButton
