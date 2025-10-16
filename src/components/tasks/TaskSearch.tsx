import { TextField } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { useEffect } from 'react'
import { useDebouncedCallback } from 'use-debounce'

interface TaskSearchProps {
  /** Control if the input is disabled and does not fire search. */
  disabled: boolean

  /** Debounced search handler; receives the query string. */
  onSearch: (searchTerm: string) => void

  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * TaskSearch — debounced text input for filtering tasks.
 *
 * Triggers `onSearch(query)` 100 ms after typing pauses; pending calls are canceled on unmount.
 * Uses an outlined MUI TextField with an accessible label for screen readers.
 */
export function TaskSearch({ disabled, onSearch, sx }: TaskSearchProps) {
  const debounced = useDebouncedCallback((q: string) => onSearch(q), 100)

  useEffect(() => {
    return () => {
      debounced.cancel()
    }
  }, [debounced])

  return (
    <TextField
      variant="outlined"
      label={'Search Tasks...'}
      disabled={disabled}
      onChange={(e) => debounced(e.target.value)}
      sx={{ ...sx }}
    />
  )
}

export default TaskSearch
