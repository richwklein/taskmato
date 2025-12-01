import { Box, Typography } from '@mui/material'
import React from 'react'

export interface CircularCountdownProps {
  /** Elapsed duration ms. */
  elapsed: number

  /** Remaining duration ms. */
  remaining: number

  /** Target duration ms. */
  target: number

  /** Optional label shown inside the circle. */
  label?: string
  /** Optional size in px; defaults to 240. */
  size?: number
}

/** SVG-based circular progress that matches the reference mock (determinate). */
export function CircularCountdown({
  elapsed,
  remaining,
  target,
  label,
  size = 240,
}: CircularCountdownProps) {
  const pct = Math.min(100, Math.max(0, (elapsed / target) * 100))

  const R = size / 2 - 8
  const C = Math.PI * 2 * R
  const mm = Math.floor(remaining / 60000)
  const ss = Math.floor((remaining % 60000) / 1000)

  return (
    <Box
      position="relative"
      width={size}
      height={size}
      display="inline-flex"
      justifyContent="center"
      alignItems="center"
    >
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={R}
          strokeWidth={8}
          strokeOpacity={0.1}
          stroke="currentColor"
          fill="none"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={R}
          strokeWidth={8}
          stroke="currentColor"
          fill="none"
          strokeDasharray={C}
          strokeDashoffset={C * (1 - pct)}
          strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      </svg>
      <Box position="absolute" textAlign="center">
        <Typography variant="h4" component="div">{`${String(mm).padStart(
          2,
          '0'
        )}:${String(ss).padStart(2, '0')}`}</Typography>
        {label && (
          <Typography variant="caption" component="div" sx={{ opacity: 0.7 }}>
            {label}
          </Typography>
        )}
      </Box>
    </Box>
  )
}
