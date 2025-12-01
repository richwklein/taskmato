import { SxProps, Theme } from '@mui/material'
import { SettingsType } from '@types'

/** Props passed to a settings renderer component. */
export interface SettingsRenderProps<T extends SettingsType> {
  /** Current value of the setting. */
  value: T
  /** Called when the setting value changes. */
  onChange: (value: T) => void
  /** Optional MUI system styles. */
  sx?: SxProps<Theme>
}
