import PauseIcon from '@mui/icons-material/Pause'
import PlayArrowIcon from '@mui/icons-material/PlayArrow'
import StopIcon from '@mui/icons-material/Stop'
import { IconButton, LinearProgress, Paper, Stack, Typography } from '@mui/material'
import MuiMarkdown from 'mui-markdown'
import { useMemo } from 'react'

import { useSessionContext } from '../hooks/useSessionContext'

export interface TimerBarProps {
  /** Show the compact floating bar when a session is active. */
  enabled?: boolean
}

/** Compact, anchored floating bar that overlays existing pages when active. */
export function TimerBar({ enabled = true }: TimerBarProps) {
  const { active, isRunning, pause, resume, stop } = useSessionContext()

  const { pct, remainingText } = useMemo(() => {
    if (!active) return { pct: 0, remainingText: '00:00' }
    const elapsed = active.accrued + (isRunning ? Date.now() - active.startTime : 0)
    const pct = Math.min(100, Math.max(0, (elapsed / active.target) * 100))
    const remaining = Math.max(0, active.target - elapsed)
    const mm = Math.floor(remaining / 60000)
    const ss = Math.floor((remaining % 60000) / 1000)
    return {
      pct,
      remainingText: `${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}`,
    }
  }, [active, isRunning])

  if (!enabled || !active) return null

  return (
    <Paper
      elevation={8}
      sx={{
        position: 'fixed',
        left: 16,
        right: 16,
        bottom: 16,
        p: 1.5,
        borderRadius: 3,
        zIndex: (t) => t.zIndex.modal + 1,
      }}
    >
      <Stack direction="row" alignItems="center" spacing={2}>
        <Stack sx={{ flex: 1 }}>
          <Typography variant="body2" noWrap>
            <MuiMarkdown>{active.task.content}</MuiMarkdown>
          </Typography>
          <LinearProgress variant="determinate" value={pct} sx={{ mt: 0.5 }} />
        </Stack>
        <Typography variant="body2" sx={{ minWidth: 56, textAlign: 'right' }}>
          {remainingText}
        </Typography>
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
    </Paper>
  )
}
