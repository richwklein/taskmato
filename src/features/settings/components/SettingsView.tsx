import { DefaultLayout } from '@common/components'
import { LoadingView } from '@common/components'
import { settings, SettingsKey, SettingsTypeMap, ThemeMode } from '@common/settings'
import { SettingsType } from '@types'
import { useEffect, useMemo, useState } from 'react'

import { useSettingsService } from '../hooks/useSettingsService'
import { ApiKeySetting } from './ApiKeySetting'
import { ThemeSetting } from './ThemeSetting'

/**
 * SettingsView Component
 *
 * This settings view component is the element for the "settings" route.
 * It displays a form for saving a user's settings.
 *
 * @returns the rendered SettingsView component.
 */
export function SettingsView() {
  const service = useSettingsService()

  const [values, setValues] = useState<Partial<SettingsTypeMap> | null>(null)
  const settingsDefinitions = useMemo(() => settings.defs, [settings])

  useEffect(() => {
    let canceled = false
    const fetchSettings = async () => {
      Promise.all(
        settingsDefinitions.map(async (s) => {
          const value = await service.get(s.key)
          return [s.key, value] as [string, SettingsType]
        })
      ).then((entries) => {
        if (!canceled) {
          setValues(Object.fromEntries(entries))
        }
      })
    }
    fetchSettings()

    return () => {
      canceled = true
    }
  }, [settings, service])

  const handleChange = async <K extends SettingsKey>(key: K, newValue: SettingsTypeMap[K]) => {
    if (!values) return
    setValues((prev) => ({ ...prev, [key]: newValue }))
    await service.set(key, newValue)
  }

  if (!values) {
    return <LoadingView message="Loading settings..." />
  }

  return (
    <DefaultLayout scroll={true} sx={{ gap: 4, mt: 2 }}>
      <ApiKeySetting
        value={values['todoist.api.key'] as string}
        onChange={(v) => handleChange('todoist.api.key', v)}
      />
      <ThemeSetting
        value={values['ui.theme.mode'] as ThemeMode}
        onChange={(v) => handleChange('ui.theme.mode', v)}
      />
    </DefaultLayout>
  )
}
