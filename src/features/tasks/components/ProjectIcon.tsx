import InboxIcon from '@mui/icons-material/Inbox'
import TagIcon from '@mui/icons-material/Tag'
import TodayIcon from '@mui/icons-material/Today'
import type { SxProps, Theme } from '@mui/material/styles'
import { PROJECT_TYPE, type ProjectType } from '@types'

interface ProjectIconProps {
  /** The type of project. Special icons are used for Inbox, and Today projects. */
  type: ProjectType
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * ProjectIcon — returns the appropriate icon for a project type.
 */
export function ProjectIcon({ type, sx }: ProjectIconProps) {
  let Icon = TagIcon

  if (type === PROJECT_TYPE.Today) {
    Icon = TodayIcon
  } else if (type === PROJECT_TYPE.Inbox) {
    Icon = InboxIcon
  }

  return <Icon sx={{ ...sx }} />
}

export default ProjectIcon
