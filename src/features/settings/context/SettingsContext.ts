// src/features/settings/context/SettingsContext.tsx
import { createContext } from 'react'

import type SettingsService from '../services/SettingsService'

/**
 * React context providing access to the SettingsService.
 * Allows components and hooks to read and update settings without prop-drilling.
 */
export const SettingsContext = createContext<SettingsService | null>(null)
