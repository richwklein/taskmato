import { GlobalToolbar } from '@components/global/GlobalToolbar'
import { ThemeModeApplier } from '@components/settings/ThemeModeApplier'
import { SettingsView } from '@features/settings'
import { StatisticsView } from '@features/statistics'
import TasksProvider from '@features/tasks/tasks-provider'
import TasksView from '@features/tasks/tasks-view'
import { Box, CircularProgress } from '@mui/material'
import { db } from '@utils/db'
import { JSX, useEffect, useState } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'

/**
 * A wrapper component to enforce API key presence.
 *
 * If the API key is not set in localStorage, it redirects to the SettingsView.
 */
function RequireApiKey({ children }: { children: JSX.Element }) {
  const [isLoading, setLoading] = useState(true)
  const [hasKey, setHasKey] = useState(false)

  useEffect(() => {
    const fetchApiKey = async () => {
      const keySetting = await db.settings.get('todoist.api.key')
      setHasKey(!!(keySetting && keySetting.value))
      setLoading(false)
    }
    fetchApiKey()
  }, [])

  if (isLoading) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          height: '100%',
        }}
      >
        <CircularProgress />
      </Box>
    )
  }

  if (!hasKey) {
    return <Navigate to="/settings" replace />
  }
  return children
}

/**
 * The main application component for Taskmato.
 *
 * This component displays the global toolbar and  sets up the routing for the
 * application using React Router. It defines routes for the Home, Statistics,
 * and Settings pages.
 */
function Taskmato() {
  return (
    <TasksProvider>
      <ThemeModeApplier />
      <GlobalToolbar />
      <Routes>
        <Route path="settings" element={<SettingsView />} />
        <Route
          path="statistics"
          element={
            <RequireApiKey>
              <StatisticsView />
            </RequireApiKey>
          }
        />
        <Route
          path="/"
          element={
            <RequireApiKey>
              <TasksView />
            </RequireApiKey>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </TasksProvider>
  )
}

export default Taskmato
