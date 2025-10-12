import RefreshIcon from '@mui/icons-material/Refresh'
import { IconButton } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

type RefreshButtonProps = {
  disabled: boolean
  onRefresh: () => void
  onHardRefresh: () => void
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
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
