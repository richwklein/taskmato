import SettingsService from '../services/SettingsService'
import { SettingsContext } from './SettingsContext'

export interface SettingsProviderProps {
  /** SettingsService instance to fetch and store settings. */
  service: SettingsService

  /** React children to be wrapped by the provider. */
  children: React.ReactNode
}

/**
 * SettingsProvider Component
 */
export function SettingsProvider({ service, children }: SettingsProviderProps) {
  return <SettingsContext.Provider value={service}>{children}</SettingsContext.Provider>
}

export default SettingsProvider
