import { CircularProgress, Typography } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { useEffect, useState } from 'react'

import { DefaultLayout } from './DefaultLayout'

export type LoadingViewProps = {
  /** Optional message to display. Defaults to "Loading..." */
  message?: string

  /** Delay (in ms) before showing the loading view to avoid flicker. */
  delay?: number

  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * LoadingView — Delayed spinner + message for long-running loads.
 *
 * Renders nothing until `delay` ms have passed (to avoid flicker), then shows a
 * centered `CircularProgress` and optional `message`. Timer is cleared on unmount.
 */
export function LoadingView({ message = 'Loading...', delay = 250, sx }: LoadingViewProps) {
  const [show, setShow] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setShow(true), delay)
    return () => clearTimeout(timer)
  }, [delay])

  if (!show) return null

  return (
    <DefaultLayout center={true} scroll={false} sx={sx}>
      <CircularProgress size={48} />
      <Typography variant="h6" color="text.secondary" sx={{ mt: 2 }}>
        {message}
      </Typography>
    </DefaultLayout>
  )
}
