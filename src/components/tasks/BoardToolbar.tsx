import { TaskSearch } from '@components/tasks'
import { RefreshButton } from '@features/tasks/components/RefreshButton'
import { SidebarToggle } from '@features/tasks/components/SidebarToggle'
import { Toolbar } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

interface BoardToolbarProps {
  /** Whether interactive elements (search, refresh) are disabled. */
  disabled: boolean
  /** True on md+ breakpoints; affects sidebar toggle wording. */
  isDesktop: boolean
  /** Whether the sidebar is currently open (visible). */
  isSidebarOpen: boolean
  /** Called when the sidebar toggle button is clicked. */
  onSidebarToggle: () => void
  /** Called when a task search is initiated. */
  onSearch: (searchTerm: string) => void
  /** Called when a standard data refresh is requested. */
  onRefresh: () => void
  /** Called when a full (hard) refresh is requested, e.g. cache clear + sync. */
  onHardRefresh: () => void
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * BoardToolbar — task board actions and sidebar control.
 *
 * Provides quick access to sidebar visibility, task search, and data refresh controls.
 * The toolbar adapts between mobile and desktop layouts, forwarding styles via `sx`
 * for seamless integration with surrounding layout and theme.
 */
export function BoardToolbar({
  disabled,
  isDesktop,
  isSidebarOpen,
  onSidebarToggle,
  onSearch,
  onRefresh,
  onHardRefresh,
  sx,
}: BoardToolbarProps) {
  return (
    <Toolbar
      disableGutters
      sx={{
        pl: 2,
        justifyContent: 'space-between',
        ...sx,
      }}
    >
      <SidebarToggle
        isPersistent={isDesktop}
        isOpen={isSidebarOpen}
        onToggle={onSidebarToggle}
        sx={{ mr: 2 }}
      />
      <TaskSearch disabled={disabled} onSearch={onSearch} sx={{ mr: 2, flexGrow: 1 }} />
      <RefreshButton disabled={disabled} onRefresh={onRefresh} onHardRefresh={onHardRefresh} />
    </Toolbar>
  )
}

export default BoardToolbar
