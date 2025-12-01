import { ToolbarOffset } from '@common/components'
import {
  Box,
  Divider,
  Drawer,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
} from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { Project } from '@types'

import { ProjectIcon } from './ProjectIcon'

interface ProjectsSidebarProps {
  /** All projects to render, ordered as they should appear. */
  projects: Project[]
  /** The currently selected project id (controls highlighting). */
  selectedId?: string
  /** Called with the project id when a list item is clicked. */
  onSelect: (projectId: string) => void
  /** True on md+ breakpoints; switches Drawer to `persistent` variant. */
  isDesktop: boolean
  /** Whether the Drawer is open (visible). */
  isOpen: boolean
  /** Called when the Drawer requests to close. */
  onClosing: () => void
  /** Called after the Drawer transition completes (open or close). */
  onClosed: () => void
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * SidebarNavigation — responsive project selector in a Drawer.
 *
 * A`Drawer` that lists all projects and highlights the currently selected one.
 * On desktop (`isDesktop=true`) it uses a **persistent** drawer; on mobile it uses
 * a **temporary** drawer with a backdrop.
 */
export function ProjectsSidebar({
  projects,
  selectedId,
  onSelect,
  isDesktop,
  isOpen,
  onClosing,
  onClosed,
  sx,
}: ProjectsSidebarProps) {
  const renderListItems = () => {
    const items: React.ReactNode[] = []
    let hasInsertedDivider = false

    projects.forEach((project) => {
      if (!hasInsertedDivider && project.type === 'project') {
        items.push(<Divider key="divider" />)
        hasInsertedDivider = true
      }

      items.push(
        <ListItemButton
          key={project.id}
          sx={{ pl: project.parentId !== null ? 4 : 2 }}
          selected={project.id === selectedId}
          aria-selected={project.id === selectedId}
          onClick={() => onSelect(project.id)}
        >
          <ListItemIcon>
            <ProjectIcon type={project.type} sx={{ color: project.color.hex, mr: 1 }} />
          </ListItemIcon>
          <ListItemText>{project.name}</ListItemText>
        </ListItemButton>
      )
    })

    return items
  }

  return (
    <Drawer
      variant={isDesktop ? 'persistent' : 'temporary'}
      open={isOpen}
      onTransitionEnd={() => onClosed()}
      onClose={() => onClosing()}
      slotProps={{
        root: {
          keepMounted: isDesktop ? false : true,
        },
      }}
      sx={{
        width: 240,
        flexShrink: 0,
        [`& .MuiDrawer-paper`]: { width: 240, boxSizing: 'border-box' },
        ...sx,
      }}
    >
      <ToolbarOffset />
      <Box sx={{ overflow: 'auto', mt: 2 }}>
        <List dense>{renderListItems()}</List>
      </Box>
    </Drawer>
  )
}
