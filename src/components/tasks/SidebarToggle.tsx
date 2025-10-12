import MenuIcon from '@mui/icons-material/Menu'
import MenuOpenIcon from '@mui/icons-material/MenuOpen'
import { IconButton } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

export interface SidebarToggleProps {
  isDesktop: boolean
  isOpen: boolean
  onToggle: () => void
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * SidebarToggle Component.
 * A component that is used on the BoardToolbar to toggle open / closed the {@link SidebarNavigation}.
 *
 * @param The {@link SidebarToggleProps} props
 * @returns The rendered component.
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
