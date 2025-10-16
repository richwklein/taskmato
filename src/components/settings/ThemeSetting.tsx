// ThemeSetting.tsx
import { FormControl, FormControlLabel, FormLabel, Radio, RadioGroup } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import settingsService from '@services/SettingsService'
import type { ThemeMode } from '@utils/settings'
import React, { useEffect, useState } from 'react'

type ThemeSettingProps = {
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * ThemeSetting — user control for selecting the app’s color mode.
 */
export function ThemeSetting({ sx }: ThemeSettingProps) {
  const [themeMode, setThemeMode] = useState<ThemeMode>('system')

  useEffect(() => {
    const loadSetting = async () => {
      const setting = await settingsService.get('ui.theme.mode')
      setThemeMode(setting)
    }
    loadSetting()
  }, [])

  const handleChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = event.target.value as ThemeMode
    setThemeMode(newValue)
    await settingsService.set('ui.theme.mode', newValue)
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
