import PauseIcon from '@mui/icons-material/Pause'
import PlayArrowIcon from '@mui/icons-material/PlayArrow'
import StopIcon from '@mui/icons-material/Stop'
import SwapHorizIcon from '@mui/icons-material/SwapHoriz'
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Typography,
} from '@mui/material'
import MuiMarkdown from 'mui-markdown'
import { useEffect, useMemo } from 'react'

import { useSessionContext } from '../hooks/useSessionContext'
import { CircularCountdown } from './CircularCountdown'

export interface TimerModalProps {
  /** Control visibility of the modal. */
  open: boolean
  /** Close callback for the parent view. */
  onClose: () => void
}

/** Full circular timer modal with pause/stop/swap actions. */
export function TimerModal({ open, onClose }: TimerModalProps) {
  const { active, isRunning, pause, resume, stop, switchTask } = useSessionContext()

  // Derive elapsed from active timer.
  const { elapsed, remaining, target } = useMemo(() => {
    if (!active) return { pct: 0, elapsed: 0, remaining: 0, target: 0 }
    const elapsed = active.accrued + (isRunning ? Date.now() - active.startTime : 0)
    const remaining = Math.max(0, active.target - elapsed)
    return {
      elapsed,
      remaining,
      target: active.target,
    }
  }, [active, isRunning])

  // Close the modal automatically if no active session.
  useEffect(() => {
    if (open && !active) onClose()
  }, [open, active, onClose])

  if (!active) return null

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <Typography variant="h6">
            <MuiMarkdown>{active.task.content}</MuiMarkdown>
          </Typography>
          <Stack direction="row" spacing={1}>
            <IconButton aria-label="Switch task" onClick={() => switchTask?.(active.task)}>
              <SwapHorizIcon />
            </IconButton>
            <IconButton
              aria-label={isRunning ? 'Pause' : 'Resume'}
              onClick={() => (isRunning ? pause() : resume())}
            >
              {isRunning ? <PauseIcon /> : <PlayArrowIcon />}
            </IconButton>
            <IconButton aria-label="Stop" onClick={() => stop('manual')}>
              <StopIcon />
            </IconButton>
          </Stack>
        </Stack>
      </DialogTitle>
      <DialogContent>
        <Stack alignItems="center" py={2}>
          <CircularCountdown
            remaining={remaining}
            elapsed={elapsed}
            target={target}
            label={active.phase === 'focus' ? 'Operation Time' : 'Break'}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={() => onClose()}>Hide</Button>
      </DialogActions>
    </Dialog>
  )
}
