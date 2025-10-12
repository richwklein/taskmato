import { GlobalToolbar, ThemeModeApplier } from '@components/global'
import { SettingsView } from '@features/settings'
import TasksProvider from '@features/tasks/tasks-provider'
import { StatisticsPage, TasksPage } from '@pages'
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
        <Route path="statistics" element={<StatisticsPage />} />
        <Route path="/" element={<TasksPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </TasksProvider>
  )
}

export default Taskmato
