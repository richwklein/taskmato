import { GlobalToolbar } from '@components/global'
import { RequireApiKey } from '@components/global'
import { ThemeModeApplier } from '@components/settings'
import { SettingsView } from '@features/settings'
import { StatisticsView } from '@features/statistics'
import TasksProvider from '@features/tasks/tasks-provider'
import TasksView from '@features/tasks/tasks-view'
import { Navigate, Route, Routes } from 'react-router-dom'

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
