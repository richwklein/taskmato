import { TextField } from '@mui/material'
import type { SxProps, Theme } from '@mui/material/styles'
import { useEffect } from 'react'
import { useDebouncedCallback } from 'use-debounce'

interface TaskSearchProps {
  disabled: boolean
  onSearch: (searchTerm: string) => void
  /** Optional system styles forwarded to the progress component. */
  sx?: SxProps<Theme>
}

/**
 * TaskSearch component
 * A text input used for searching for tasks in the task view.
 *
 * @returns A rendered textbox for searching.
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
