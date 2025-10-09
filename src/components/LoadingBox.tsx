import { Box, CircularProgress } from '@mui/material'

type LoadingBoxProps = {
  sx?: object
}

/**
 * LoadingBox Component
 *
 * An undetermined circular loading box that displays at full height.
 * This is useful for loading states where the content is not yet available.
 *
 * @param sx - The optional style object to apply to the loading box.
 * @returns The rendered LoadingBox component.
 */
export function LoadingBox({ sx }: LoadingBoxProps) {
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

export default LoadingBox
