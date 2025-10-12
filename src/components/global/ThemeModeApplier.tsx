// ThemeModeApplier.tsx
import { useColorScheme, useMediaQuery } from '@mui/material'
import settingsService from '@services/SettingsService'
import { useEffect } from 'react'

/**
 * ThemeModeApplier — side-effect component that keeps MUI color mode in sync with user settings.
 */
export function ThemeModeApplier() {
  const { mode, setMode } = useColorScheme()
  const prefersDark = useMediaQuery('(prefers-color-scheme: dark)')

  useEffect(() => {
    let unsubscribe: (() => void) | undefined

    settingsService
      .getThemeModeWithListener((newMode) => {
        let nextMode: 'light' | 'dark'
        if (newMode === 'system') {
          nextMode = prefersDark ? 'dark' : 'light'
        } else {
          nextMode = newMode as 'light' | 'dark'
        }

        if (mode !== nextMode) setMode(nextMode)
      })
      .then((unsub) => {
        unsubscribe = unsub
      })

    return () => {
      if (unsubscribe) unsubscribe()
    }
  }, [mode, prefersDark, setMode])

  return null // no UI — just side effect
}

export default ThemeModeApplier
