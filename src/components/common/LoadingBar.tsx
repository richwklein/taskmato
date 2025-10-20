import { LinearProgress } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'

type LoadingBarProps = {
  /** Whether to show the indeterminate loading state. */
  isLoading: boolean
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * LoadingBar — a persistent linear progress indicator.
 *
 * - When `isLoading` is true, shows an **indeterminate** LinearProgress.
 * - When `isLoading` is false, renders a **determinate** LinearProgress at 0% with a transparent track.
 *   Keeping it mounted prevents layout shift for content below.
 */
export function LoadingBar({ isLoading, sx }: LoadingBarProps) {
  return (
    <LinearProgress
      variant={isLoading ? 'indeterminate' : 'determinate'}
      value={isLoading ? undefined : 0}
      sx={{
        opacity: isLoading ? 1 : 0,
        ...sx,
      }}
    />
  )
}
