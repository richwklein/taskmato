import { LinearProgress } from '@mui/material'

type LoadingBarProps = {
  isLoading: boolean
  sx?: object
}

/**
 * LoadingBar Component
 *
 * While loading is true, displays a linear loading bar. When loading is false,
 * displays an empty bar of the same height.
 *
 * @param isLoading - Indicates whether the loading bar should be displayed.
 * @param sx - The optional style object to apply to the loading bar.
 * @returns The rendered LoadingBar component.
 */
export function LoadingBar({ isLoading, sx }: LoadingBarProps) {
  return (
    <LinearProgress
      variant={isLoading ? 'indeterminate' : 'determinate'}
      value={isLoading ? undefined : 0}
      sx={{
        height: 4,
        opacity: isLoading ? 1 : 0,
        ...sx,
      }}
    />
  )
}

export default LoadingBar
