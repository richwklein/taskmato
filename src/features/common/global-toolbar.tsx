import AnalyticsIcon from '@mui/icons-material/Analytics'
import HomeIcon from '@mui/icons-material/Home'
import MoreTimeIcon from '@mui/icons-material/MoreTime'
import SettingsIcon from '@mui/icons-material/Settings'
import { AppBar, ButtonGroup, IconButton, Toolbar, Typography } from '@mui/material'
import { Link } from 'react-router-dom'

interface GlobalToolbarProps {
  sx?: object
}

/**
 * GlobalToolbar Component
 *
 * This component displays the title of the application and provides global
 * navigation including buttons for Home, Statistics, and Settings pages.
 *
 * @param sx - The optional style object to apply to the toolbar.
 * @returns The rendered GlobalToolbar component.
 */
export function GlobalToolbar({ sx }: GlobalToolbarProps) {
  return (
    <AppBar id="app-toolbar" position="static" sx={{ ...sx }}>
      <Toolbar>
        {/* TODO replace icon */}
        <MoreTimeIcon color="inherit" sx={{ mr: 1 }} />
        <Typography variant="h6" color="inherit" component="div" sx={{ flexGrow: 1 }}>
          {'Taskmato'}
        </Typography>
        <ButtonGroup>
          <IconButton color="inherit" aria-label="Home" component={Link} to="/">
            <HomeIcon />
          </IconButton>
          <IconButton color="inherit" aria-label="Statistics" component={Link} to="statistics">
            <AnalyticsIcon />
          </IconButton>
          <IconButton color="inherit" aria-label="Settings" component={Link} to="settings">
            <SettingsIcon />
          </IconButton>
        </ButtonGroup>
      </Toolbar>
    </AppBar>
  )
}

export default GlobalToolbar
