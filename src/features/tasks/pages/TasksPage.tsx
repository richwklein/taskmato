/**
 * The route component for the main tasks view.
 *
 * This component is responsible for mounting the feature-level TasksView
 * and handling any page-level layout or suspense boundaries.
 */
import { RequireApiKey } from '../components/RequireApiKey'
import { TasksView } from '../components/TasksView'

export function TasksPage() {
  return (
    <RequireApiKey>
      <TasksView />
    </RequireApiKey>
  )
}
