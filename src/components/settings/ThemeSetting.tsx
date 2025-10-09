// ThemeSetting.tsx
import { FormControl, FormControlLabel, FormLabel, Radio, RadioGroup } from '@mui/material'
import type { ThemeMode } from '@services/SettingsService'
import settingsService from '@services/SettingsService'
import React, { useEffect, useState } from 'react'

type ThemeSettingProps = {
  sx?: object
}

/**
 * ThemeSetting Component
 *
 * Allows the user to select the application's theme mode (light, dark, or system).
 * Saves the preference to the settings database.
 *
 * @returns A component for selecting the application's theme mode.
 */
export function ThemeSetting({ sx }: ThemeSettingProps) {
  const [themeMode, setThemeMode] = useState<ThemeMode>('system')

  useEffect(() => {
    const loadSetting = async () => {
      const setting = await settingsService.getThemeMode()
      setThemeMode(setting)
    }
    loadSetting()
  }, [])

  const handleChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = event.target.value as ThemeMode
    setThemeMode(newValue)
    await settingsService.setThemeMode(newValue)

    // Trigger a theme update
  }

  return (
    <FormControl component="fieldset" sx={{ ...sx }}>
      <FormLabel component="legend">Theme</FormLabel>
      <RadioGroup row value={themeMode} onChange={handleChange}>
        <FormControlLabel value="light" control={<Radio />} label="Light" />
        <FormControlLabel value="dark" control={<Radio />} label="Dark" />
        <FormControlLabel value="system" control={<Radio />} label="System" />
      </RadioGroup>
    </FormControl>
  )
}
