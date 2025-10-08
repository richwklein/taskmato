import { ProjectSelect } from '@features/tasks'
import RefreshButton from '@features/tasks/refresh-button'
import { useTasksContext } from '@features/tasks/use-tasks'
import { TextField, Toolbar } from '@mui/material'

interface TasksToolbarProps {
  sx?: object
}

/**
 * TasksToolbar Component
 *
 * This is a toolbar used to control the data shown in the tasks view.
 * It includes a refresh button, a project selector and a search input for finding tasks within the current project.
 *
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered TaskToolbar component.
 */
export function TasksToolbar({ sx }: TasksToolbarProps) {
  const { isLoading, projects, view, showProject } = useTasksContext()

  const handleProjectChange = (projectId: string) => {
    showProject(projectId)
  }

  return (
    <Toolbar
      disableGutters
      sx={{
        justifyContent: 'space-between',
        ...sx,
      }}
    >
      <ProjectSelect
        disable={isLoading}
        projects={projects}
        selectedId={view?.projectId ?? null}
        onSelect={handleProjectChange}
      />
      <TextField
        variant="outlined"
        label="Search Tasks..."
        //value={dataContext.searchQuery}
        disabled={isLoading}
        // onChange={handleSearchChange}
        sx={{ mr: 2, flexGrow: 1 }}
        // TODO debounce the search calls
        // TODO move to it's own component
      />
      <RefreshButton />
    </Toolbar>
  )
}

export default TasksToolbar
