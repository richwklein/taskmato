import { useSyncTasks } from '@features/tasks'
import Visibility from '@mui/icons-material/Visibility'
import VisibilityOff from '@mui/icons-material/VisibilityOff'
import {
  Box,
  Button,
  FormControl,
  FormHelperText,
  IconButton,
  InputAdornment,
  InputLabel,
  OutlinedInput,
  Stack,
} from '@mui/material'
import { useState } from 'react'

import { SettingsRenderProps } from '../model/SettingsRender'

const INPUT_ID = 'todoist-api-key'
const HELPER_ID = 'api-key-helper'

/**
 * Renders a text field allowing the user to input and save their Todoist API key.
 */
export function ApiKeySetting({ value, onChange, sx }: SettingsRenderProps<string>) {
  const [showApiKey, setShowApiKey] = useState(false)
  const [localValue, setLocalValue] = useState(value as string)

  const inputValue = localValue ?? ''
  const isInvalid = inputValue.trim() === ''

  const syncTasks = useSyncTasks()

  const handleSave = () => {
    onChange(localValue)
    syncTasks(true)
  }

  const toggleShowApiKey = () => {
    setShowApiKey((prev) => !prev)
  }

  return (
    <Stack spacing={1} sx={sx}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <FormControl
          variant="outlined"
          fullWidth
          required
          error={isInvalid}
          aria-describedby={HELPER_ID}
        >
          <InputLabel htmlFor={INPUT_ID}>Todoist API Key</InputLabel>
          <OutlinedInput
            id={INPUT_ID}
            type={showApiKey ? 'text' : 'password'}
            value={inputValue}
            autoComplete={'off'}
            onChange={(e) => setLocalValue(e.target.value)}
            error={isInvalid}
            label="Todoist API Key *"
            endAdornment={
              <InputAdornment position="end">
                <IconButton
                  onClick={toggleShowApiKey}
                  edge="end"
                  aria-label={showApiKey ? 'Hide API key' : 'Show API key'}
                >
                  {showApiKey ? <VisibilityOff /> : <Visibility />}
                </IconButton>
              </InputAdornment>
            }
          />
        </FormControl>
        <Button variant={'contained'} onClick={handleSave} disabled={localValue === value}>
          Save
        </Button>
      </Box>
      <FormHelperText id={HELPER_ID} error={isInvalid}>
        {'API key required to sync with Todoist. Find it in your Todoist settings.'}
      </FormHelperText>
    </Stack>
  )
}
