import DataProvider from '@context/data/DataProvider'
import { LoadingBar } from '@features/common'
import { GlobalToolbar } from '@features/common'
import { SettingsView } from '@features/settings'
import { StatisticsView } from '@features/statistics'
import TasksView from '@features/tasks/tasks-view'
import { CssBaseline, ThemeProvider } from '@mui/material'
import theme from '@styles/theme'
import { JSX } from 'react'
import { BrowserRouter as Router, Navigate, Route, Routes } from 'react-router-dom'

/**
 * A wrapper component to enforce API key presence.
 *
 * If the API key is not set in localStorage, it redirects to the SettingsView.
 */
function RequireApiKey({ children }: { children: JSX.Element }) {
  const apiKey = localStorage.getItem('todoistApiKey')
  if (!apiKey) {
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
    <ThemeProvider theme={theme} noSsr>
      <CssBaseline />
      <DataProvider>
        <Router>
          <GlobalToolbar />
          <LoadingBar sx={{ mb: 1 }} />
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
        </Router>
      </DataProvider>
    </ThemeProvider>
  )
}

export default Taskmato
