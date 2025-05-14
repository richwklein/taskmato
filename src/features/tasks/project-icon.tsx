import InboxIcon from '@mui/icons-material/Inbox'
import TagIcon from '@mui/icons-material/Tag'
import TodayIcon from '@mui/icons-material/Today'
import { ProjectType } from '@types'

interface ProjectIconProps {
  type: ProjectType
  sx?: object
}

/**
 * ProjectIcon Component
 *
 * A component for rendering the icon associated with a project. Different icons
 * are used for the Today and Inbox projects.
 *
 * @param type - The type of the project
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered ProjectIcon component.
 */
export function ProjectIcon({ type, sx }: ProjectIconProps) {
  let Icon = TagIcon
  if (type === ProjectType.Today) {
    Icon = TodayIcon
  } else if (type === ProjectType.Inbox) {
    Icon = InboxIcon
  }

  return <Icon sx={{ ...sx }} />
}

export default ProjectIcon
