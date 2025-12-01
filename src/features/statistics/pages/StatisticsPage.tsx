import { DefaultLayout } from '@common/components'
import { Typography } from '@mui/material'

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
    <DefaultLayout center={true} scroll={false}>
      <Typography variant="h6">{'Statistics coming soon!'}</Typography>
    </DefaultLayout>
  )
}
