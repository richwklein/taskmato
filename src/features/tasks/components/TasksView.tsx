// src/features/tasks/components/TasksView.tsx
import { DefaultLayout } from '@common/components'
import { LoadingBar } from '@components/common'
import { BoardToolbar } from '@components/tasks'
import { TimerModal } from '@features/session/components/TimerModal'
import { Box } from '@mui/material'

import { useSidebarState } from '../hooks/useSidebarState'
import { useTasksContext } from '../hooks/useTasksContext'
import { useTaskTimer } from '../hooks/useTaskTimer'
import { ProjectsSidebar } from './ProjectsSidebar'
import TasksSections from './TasksSection'

/**
 * Displays the main task view including sidebar, board toolbar, and task sections.
 * Handles UI interactions and session starting logic.
 */
export function TasksView() {
  const { isLoading, isInitialized, view, showProject, filterTasks, sync } = useTasksContext()
  const { isDesktop, isOpen, toggleSidebar, handleClosing, handleClosed } = useSidebarState()
  const { isModalOpen, handleStartTimer, handleCloseModal } = useTaskTimer()

  const drawerWidth = 240

  return (
    <DefaultLayout sx={{ p: 0, pt: 2 }}>
      <TimerModal open={isModalOpen} onClose={handleCloseModal} />
      <ProjectsSidebar
        projects={view?.projects || []}
        selectedId={view?.projectId}
        onSelect={showProject}
        isDesktop={isDesktop}
        isOpen={isOpen}
        onClosing={handleClosing}
        onClosed={handleClosed}
      />
      <LoadingBar isLoading={!isInitialized || isLoading} sx={{ mb: 2 }} />
      <Box
        sx={(theme) => ({
          ml: { md: isOpen ? `${drawerWidth}px` : 0 },
          transition: theme.transitions.create('margin-left', {
            duration: theme.transitions.duration.shorter,
          }),
        })}
      >
        <BoardToolbar
          sx={{ mb: 2 }}
          disabled={isLoading || !isInitialized}
          isDesktop={isDesktop}
          isSidebarOpen={isOpen}
          onSidebarToggle={toggleSidebar}
          onSearch={filterTasks}
          onRefresh={() => sync(false)}
          onHardRefresh={() => sync(true)}
        />
        <TasksSections
          sections={view?.sections || []}
          tasks={view?.tasks || []}
          onStartTask={handleStartTimer}
          sx={{ overflowY: 'auto', height: `calc(100vh - 200px)`, pr: 2 }}
        />
      </Box>
    </DefaultLayout>
  )
}
