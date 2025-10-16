import { LoadingBar, RequireApiKey, ToolbarOffset } from '@components/common'
import { BoardToolbar } from '@components/tasks'
import { SidebarNavigation } from '@components/tasks'
import { TasksSections } from '@features/tasks/task-sections'
import { useTasksContext } from '@features/tasks/use-tasks'
import { Box, useMediaQuery } from '@mui/material'
import settingsService from '@services/SettingsService'
import theme from '@styles/theme'
import { useEffect, useRef, useState } from 'react'

/**
 * TasksPage component
 *
 * This home page component is the element for the index route.
 * It displays the list of tasks and let's you start a Pomodoro session.
 *
 * @returns the rendered Home component.
 */
export function TasksPage() {
  const { isLoading, isInitialized, view, showProject, filterTasks, sync } = useTasksContext()
  const [isOpen, setIsOpen] = useState(true)
  const [isClosing, setIsClosing] = useState(false)
  const isDesktop = useMediaQuery(theme.breakpoints.up('md')) // true on md+
  const prevIsDesktopRef = useRef(isDesktop)

  const drawerWidth = 240

  const handleSidebarClosing = () => {
    setIsClosing(true)
    setIsOpen(false)
  }

  const handleSidebarClosed = () => {
    setIsClosing(false)
  }

  const handleDrawerToggle = async () => {
    if (isClosing) return
    const newState = !isOpen
    setIsOpen(newState)

    // Save setting if desktop
    if (isDesktop) {
      await settingsService.set('ui.sidebar.open', newState)
    }
  }

  useEffect(() => {
    let canceled = false
    const fetchOpen = async () => {
      const open = await settingsService.get('ui.sidebar.open')
      if (!canceled) {
        setIsOpen(open)
      }
    }

    // fetch the open state on first load or switching settings
    if (!prevIsDesktopRef.current && isDesktop) {
      fetchOpen()
    }
    prevIsDesktopRef.current = isDesktop

    //Marks the call as canceled to prevent setting state async on unmount
    return () => {
      canceled = true
    }
  }, [isDesktop])

  return (
    <RequireApiKey>
      <SidebarNavigation
        projects={view?.projects || []}
        selectedId={view?.projectId}
        onSelect={showProject}
        isDesktop={isDesktop}
        isOpen={isOpen}
        onClosing={handleSidebarClosing}
        onClosed={handleSidebarClosed}
      />
      <Box
        component={'main'}
        sx={(theme) => ({
          mt: 0,
          flexGrow: 1,
          ml: { md: isOpen ? `${drawerWidth}px` : 0 },
          transition: theme.transitions.create('margin-left', {
            duration: theme.transitions.duration.shorter,
          }),
        })}
      >
        <ToolbarOffset />
        <LoadingBar isLoading={!isInitialized || isLoading} sx={{ mb: 2 }} />
        <Box sx={{ px: 2 }}>
          <BoardToolbar
            sx={{ mb: 2 }}
            disabled={isLoading || !isInitialized}
            isDesktop={isDesktop}
            isSidebarOpen={isOpen}
            onSidebarToggle={handleDrawerToggle}
            onSearch={filterTasks}
            onRefresh={() => sync(false)}
            onHardRefresh={() => sync(true)}
          />
          <TasksSections sections={view?.sections || []} tasks={view?.tasks || []} />
        </Box>
      </Box>
    </RequireApiKey>
  )
}

export default TasksPage
