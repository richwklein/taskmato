import { RequireApiKey } from '@components/common'
import { Box, Typography } from '@mui/material'

/**
 * StatisticsPage Component
 *
 * This statistics pages component is the element for the "statistics" route.
 * It displays statistics about previously completed tasks.
 *
 * @returns the rendered {@link StatisticsPage} component.
 */
export function StatisticsPage() {
  return (
    <RequireApiKey>
      <Box component={'main'} sx={{ mt: 2, px: 2 }}>
        <Typography variant="h5" gutterBottom>
          {'Statistics'}
        </Typography>
      </Box>
    </RequireApiKey>
  )
}

export default StatisticsPage
