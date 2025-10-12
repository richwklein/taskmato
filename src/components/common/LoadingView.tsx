import { Box, CircularProgress } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

type LoadingViewProps = {
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * LoadingView — centered, full-height spinner container.
 * This is useful for loading states where the content is not yet available.
 */
export function LoadingView({ sx }: LoadingViewProps) {
  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100%',
        ...sx,
      }}
    >
      <CircularProgress />
    </Box>
  )
}

export default LoadingView
