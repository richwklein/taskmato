import { useSettingsService } from '@features/settings/hooks/useSettingsService'
import { useColorScheme, useMediaQuery } from '@mui/material'
import { useEffect } from 'react'

/**
 * Applies the user's preferred color scheme (light, dark, or system) to the MUI theme.
 *
 * This component listens to theme mode changes from {@link SettingsService}
 * (`ui.theme.mode`) and updates MUI’s color scheme accordingly using `useColorScheme()`.
 *
 * - When the setting is `"light"` or `"dark"`, that mode is applied directly.
 * - When the setting is `"system"`, the current system preference is detected via
 *   `prefers-color-scheme: dark` and applied dynamically.
 * - The listener automatically cleans up on unmount.
 */
export function ThemeModeApplier() {
  const { mode, setMode } = useColorScheme()
  const prefersDark = useMediaQuery('(prefers-color-scheme: dark)')
  const settings = useSettingsService()

  useEffect(() => {
    let unsubscribe: (() => void) | undefined
    let canceled = false

    settings
      .getWithListener('ui.theme.mode', (newMode) => {
        if (canceled) return

        let nextMode: 'light' | 'dark'
        if (newMode === 'system') {
          nextMode = prefersDark ? 'dark' : 'light'
        } else {
          nextMode = newMode as 'light' | 'dark'
        }

        if (mode !== nextMode) setMode(nextMode)
      })
      .then((unsub) => {
        if (canceled) {
          unsub()
        } else {
          unsubscribe = unsub
        }
      })

    return () => {
      canceled = true
      if (unsubscribe) unsubscribe()
    }
  }, [mode, prefersDark, setMode, settings])

  return null // no UI — just side effect
}
