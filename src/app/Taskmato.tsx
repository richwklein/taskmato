import { SettingsPage } from '@features/settings'
import { StatisticsPage } from '@features/statistics'
import { TasksPage } from '@features/tasks'
import { Navigate, Route, Routes } from 'react-router-dom'

import { GlobalToolbar } from './components/GlobalToolbar'
import { ThemeModeApplier } from './components/ThemeModeApplier'
import { GlobalProvider } from './context/GlobalProvider'

/**
 * The root application component for **Taskmato**.
 *
 * This component composes the global application shell — including the
 * theme applier, global toolbar, and top-level route definitions.
 *
 * It uses {@link GlobalProvider} to inject feature services and state contexts,
 * and React Router to map URLs to feature pages.
 *
 * Unrecognized routes automatically redirect to `/`.
 */
export default function Taskmato() {
  return (
    <GlobalProvider>
      <ThemeModeApplier />
      <GlobalToolbar />
      <Routes>
        <Route path="settings" element={<SettingsPage />} />
        <Route path="statistics" element={<StatisticsPage />} />
        <Route index path="/" element={<TasksPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </GlobalProvider>
  )
}
