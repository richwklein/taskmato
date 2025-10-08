import { db } from '@features/common/db'
import useTasksContext from '@features/tasks/use-tasks'
import { Visibility, VisibilityOff } from '@mui/icons-material'
import { Box, Button, IconButton, InputAdornment, TextField, Typography } from '@mui/material'
import { useState } from 'react'

/**
 * SettingsView Component
 *
 * This settings view component is the element for the "settings" route.
 * It displays a form for saving a user's settings.
 *
 * @returns the rendered SettingsView component.
 */
export function SettingsView() {
  const [apiKey, setApiKey] = useState(localStorage.getItem('todoistApiKey') || '')
  const [showApiKey, setShowApiKey] = useState(false)
  const { sync } = useTasksContext()

  const handleSave = async () => {
    // Save the API key (e.g., to localStorage or a backend)
    // TODO do this in a more secure way
    // TODO move to a context and hook
    await db.settings.put({ key: 'todoist.api.key', value: apiKey })
    sync(true)
    alert('API key saved successfully!')
  }

  const toggleShowApiKey = () => {
    setShowApiKey((prev) => !prev)
  }

  return (
    <Box sx={{ p: 3, maxWidth: 600, mx: 'auto' }}>
      <Typography variant="h5" gutterBottom>
        Settings
      </Typography>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <TextField
          label="Todoist API Key"
          variant="outlined"
          type={showApiKey ? 'text' : 'password'}
          fullWidth
          value={apiKey}
          onChange={(e) => setApiKey(e.target.value)}
          InputProps={{
            endAdornment: (
              <InputAdornment position="end">
                <IconButton onClick={toggleShowApiKey} edge="end">
                  {showApiKey ? <VisibilityOff /> : <Visibility />}
                </IconButton>
              </InputAdornment>
            ),
          }}
        />
        <Button variant="contained" color="primary" onClick={handleSave}>
          Save
        </Button>
      </Box>
    </Box>
  )
}

export default SettingsView
