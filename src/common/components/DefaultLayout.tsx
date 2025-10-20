import { Box, SxProps, Theme } from '@mui/material'

import { ToolbarOffset } from './ToolbarOffset'

export interface DefaultLayoutProps {
  /** If true, centers content both vertically and horizontally. */
  center?: boolean

  /** If true, enables vertical scrolling for overflow content. */
  scroll?: boolean

  /** Page content displayed below the AppBar. */
  children: React.ReactNode

  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * DefaultLayout - Provides a consistent full-viewport layout for all pages.
 *
 * The layout is divided into two boxes:
 * - The **outer container** reserves space for the AppBar.
 * - The **inner main container** handles padding, centering, and optional scrolling.
 *
 * By default, the content grows naturally with the page and uses the browser's
 * scroll behavior. When `scroll` is true, the main area becomes a self-contained
 * scroll region that fills the viewport beneath the AppBar.
 */
export function DefaultLayout({
  center = false,
  scroll = false,
  children,
  sx,
}: DefaultLayoutProps) {
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        minHeight: '100vh',
        width: '100%',
      }}
    >
      <ToolbarOffset />
      <Box
        component="main"
        sx={{
          display: 'flex',
          flexDirection: 'column',
          flexGrow: 1,
          width: '100%',
          p: 2,
          ...(center && {
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
          }),
          ...(scroll && {
            overflowY: 'auto',
            minHeight: 0,
            WebkitOverflowScrolling: 'touch',
          }),
          ...sx,
        }}
      >
        {children}
      </Box>
    </Box>
  )
}
