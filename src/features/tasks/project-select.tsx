import { ProjectIcon } from '@features/tasks'
import {
  Box,
  Divider,
  FormControl,
  InputLabel,
  ListItemIcon,
  ListItemText,
  MenuItem,
  Select,
  SelectChangeEvent,
} from '@mui/material'
import { Project, ProjectType } from '@types'
import { JSX } from 'react/jsx-runtime'

interface ProjectSelectProps {
  disable: boolean
  projects: Project[]
  selectedId: string | null
  onSelect: (projectId: string) => void
  sx?: object
}

/**
 * ProjectSelect Component
 *
 * This component is a selector for picking which project is currently being displayed on the home page.
 *
 * @param disable - Indicate that the selection should be disabled.
 * @param projects - The list of projects to render
 * @param selectedId - The id of the selected project
 * @param onSelect - Callback function when the selection changes.
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered ProjectSelect component.
 */
export function ProjectSelect({ disable, projects, selectedId, onSelect, sx }: ProjectSelectProps) {
  // TODO do not depend on the projects sort order

  const handleChange = (event: SelectChangeEvent<string>) => {
    onSelect(event.target.value as string)
  }

  const renderSelectedProject = (selected: string) => {
    const project = projects.find((p) => p.id === selected)
    if (!project) return null

    return (
      <Box sx={{ display: 'flex', alignItems: 'center' }}>
        <ProjectIcon type={project.type} sx={{ color: project.color.hex, mr: 1 }} />
        {project.name}
      </Box>
    )
  }

  const renderMenuItems = () => {
    const items: JSX.Element[] = []
    let hasInsertedDivider = false

    projects.forEach((project) => {
      if (!hasInsertedDivider && project.type === ProjectType.Project) {
        items.push(<Divider key="divider" />)
        hasInsertedDivider = true
      }

      items.push(
        <MenuItem
          key={project.id}
          value={project.id}
          sx={{ pl: project.parentId !== null ? 4 : 2 }}
        >
          <ListItemIcon>
            <ProjectIcon type={project.type} sx={{ color: project.color.hex, mr: 1 }} />
          </ListItemIcon>
          <ListItemText>{project.name}</ListItemText>
        </MenuItem>
      )
    })

    return items
  }

  return (
    <FormControl variant="outlined" sx={{ minWidth: 400, mr: 2, ...sx }}>
      <InputLabel id="project-select-label">Project</InputLabel>
      <Select
        labelId="project-select-label"
        value={selectedId || ''}
        onChange={handleChange}
        label="Project"
        renderValue={renderSelectedProject}
        disabled={disable}
      >
        {renderMenuItems()}
      </Select>
    </FormControl>
  )
}

export default ProjectSelect
