import { ThemeMode } from '@common/settings'
import { FormControl, FormControlLabel, FormLabel, Radio, RadioGroup } from '@mui/material'

import { SettingsRenderProps } from '../model/SettingsRender'

/**
 * Renders a radio group allowing the user to select a theme mode preference.
 *
 * This setting controls the application's color scheme — light, dark, or system default.
 * When the value changes, the selected mode is passed back through the provided `onChange` handler.
 */
export function ThemeSetting({ value, onChange, sx }: SettingsRenderProps<ThemeMode>) {
  const themeMode = value as ThemeMode

  const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = event.target.value as ThemeMode
    onChange(newValue)
  }

  return (
    <FormControl component="fieldset" sx={{ ...sx }}>
      <FormLabel component="legend">Appearance</FormLabel>
      <RadioGroup row value={themeMode} onChange={handleChange}>
        <FormControlLabel value="light" control={<Radio />} label="Light" />
        <FormControlLabel value="dark" control={<Radio />} label="Dark" />
        <FormControlLabel value="system" control={<Radio />} label="System" />
      </RadioGroup>
    </FormControl>
  )
}
