import DataProvider from '@context/data/DataProvider'
import { LoadingBar } from '@features/common'
import { GlobalToolbar } from '@features/common'
import { SettingsView } from '@features/settings'
import { StatisticsView } from '@features/statistics'
import TasksView from '@features/tasks/tasks-view'
import { CssBaseline, ThemeProvider } from '@mui/material'
import theme from '@styles/theme'
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom'

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
            <Route index element={<TasksView />} />
            <Route path="statistics" element={<StatisticsView />} />
            <Route path="settings" element={<SettingsView />} />
          </Routes>
        </Router>
      </DataProvider>
    </ThemeProvider>
  )
}

export default Taskmato
