import { TasksSection } from '@components/tasks'
import { TaskGrid } from '@features/tasks'
import { Box } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { Section, Task } from '@types'

interface TasksSectionsProps {
  sections: Section[]
  tasks: Task[]
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * TasksSection Component
 *
 * A component for rendering an accordion of a tasks section with its tasks.
 *
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered TasksSection component.
 */
export function TasksSections({ sections, tasks, sx }: TasksSectionsProps) {
  // TODO if no tasks at all, show a message to add some tasks

  if (sections.length === 0) {
    return <TaskGrid tasks={tasks} sx={sx} />
  }

  return (
    <Box sx={{ ...sx }}>
      {sections.map((section: Section) => {
        const sectionTasks = tasks.filter((task: Task) => task.sectionId === section.id)
        if (sectionTasks.length === 0) {
          return null
        }

        return (
          <TasksSection key={section.id} section={section} sx={{ mb: 2 }}>
            <TaskGrid tasks={sectionTasks} />
          </TasksSection>
        )
      })}
    </Box>
  )
}

export default TasksSections
