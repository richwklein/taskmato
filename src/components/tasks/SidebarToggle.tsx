import MenuIcon from '@mui/icons-material/Menu'
import MenuOpenIcon from '@mui/icons-material/MenuOpen'
import { IconButton } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

export interface SidebarToggleProps {
  /** True when rendering in a desktop layout; affects label text. */
  isDesktop: boolean

  /** Current open/closed state of the Projects sidebar. */
  isOpen: boolean

  /** Handler to toggle the sidebar open/closed. */
  onToggle: () => void

  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * SidebarToggle — toggles the Projects sidebar from the BoardToolbar.
 *
 * Uses dynamic `title`/`aria-label` text based on layout and state, sets `aria-expanded`
 * to reflect openness, and swaps between Menu and MenuOpen icons accordingly.
 */
export function SidebarToggle({ isDesktop, isOpen, onToggle, sx }: SidebarToggleProps) {
  const title = !isDesktop
    ? 'Show Project Sidebar'
    : isOpen
      ? 'Close Projects Sidebar'
      : 'Open Projects Sidebar'

  return (
    <IconButton
      color="inherit"
      title={title}
      aria-label={title}
      aria-expanded={isOpen}
      edge="start"
      onClick={() => onToggle()}
      sx={{ ...sx }}
    >
      {isOpen ? <MenuOpenIcon /> : <MenuIcon />}
    </IconButton>
  )
}

export default SidebarToggle
