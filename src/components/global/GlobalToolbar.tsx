import AnalyticsIcon from '@mui/icons-material/Analytics'
import HomeIcon from '@mui/icons-material/Home'
import MoreTimeIcon from '@mui/icons-material/MoreTime'
import SettingsIcon from '@mui/icons-material/Settings'
import {
  AppBar,
  Box,
  ButtonGroup,
  IconButton,
  Link as MUILink,
  Toolbar,
  Typography,
} from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { Link } from 'react-router-dom'

interface GlobalToolbarProps {
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * GlobalToolbar - fixed app-wide top bar with title link and primary navigation.
 *
 * Renders an `AppBar` pinned above the Drawer (higher z-index).
 * The left side is a link to the home route that wraps the app icon and title.
 * The right side is a button group with global navigation actions (Home, Statistics, Settings).
 */
export function GlobalToolbar({ sx }: GlobalToolbarProps) {
  return (
    <AppBar
      id="app-toolbar"
      position="fixed"
      sx={{ zIndex: (theme) => theme.zIndex.drawer + 1, ...sx }}
    >
      <Toolbar>
        <Box sx={{ display: 'flex', alignItems: 'center', flexGrow: 1 }}>
          <MUILink
            component={Link}
            to="/"
            color="inherit"
            underline="none"
            aria-label="Go to Home"
            sx={{
              display: 'inline-flex',
              alignItems: 'center',
              '&:hover': { opacity: 0.9 },
              '&:focus-visible': { outline: '2px solid', outlineToolbarOffset: 2 },
            }}
          >
            {/* TODO replace icon */}
            <MoreTimeIcon color="inherit" sx={{ mr: 1 }} />
            <Typography variant="h6" color="inherit" component={'div'} role="heading">
              {'Taskmato'}
            </Typography>
          </MUILink>
        </Box>
        <ButtonGroup role="navigation" aria-label="Global Navigation">
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
