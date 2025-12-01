import { useContext } from 'react'

import { SettingsContext } from '../context/SettingsContext'
import SettingsService from '../services/SettingsService'

/**
 * Hook for accessing the SettingsService instance.
 * Throws an error if used outside of a SettingsProvider.
 */
export function useSettingsService(): SettingsService {
  const ctx = useContext(SettingsContext)
  if (!ctx) throw new Error('useSettingsService must be used within a SettingsProvider')
  return ctx
}
