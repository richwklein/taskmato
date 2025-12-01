import RefreshIcon from '@mui/icons-material/Refresh'
import { IconButton } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

type RefreshButtonProps = {
  /** Control if the button is disabled and does not fire handlers. */
  disabled: boolean

  /** Handler for a standard refresh. */
  onRefresh: () => void

  /**  Handler for a hard refresh (force-resync). */
  onHardRefresh: () => void

  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * RefreshButton — refreshes the Home view’s task data.
 *
 * Click triggers a standard refresh; Shift+Click triggers a hard refresh (force sync from Todoist).
 * Uses aria-label="Refresh" for screen readers.
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
