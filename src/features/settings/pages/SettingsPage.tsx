/**
 * The route component for the settings view.
 *
 * This component is responsible for mounting the feature-level SettingsView
 * and handling any page-level layout or suspense boundaries.
 */
import { SettingsView } from '@features/settings/components/SettingsView'

export function SettingsPage() {
  return <SettingsView />
}
