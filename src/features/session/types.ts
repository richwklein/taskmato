import { Task } from '@types'

/** A single in-progress timer run (focus or break). */
export interface ActiveRun {
  task: Task

  /** Current phase for the running timer. */
  phase: SessionPhase

  /** Timestamp the timer last started/resumed. */
  startTime: number

  /** Accrued ms from previous runs (pause/resume). */
  accrued: number

  /** Target duration ms for this phase. */
  target: number
}

/** Session phases for a Pomodoro cycle. */
export type SessionPhase = 'focus' | 'short-break' | 'long-break'

/**
 * Segment snapshot of a timer session (focus or break).
 * Saved when a segment ends and later used to build task totals and statistics.
 */
export interface SessionSnapshot {
  /** Primary key for storage of the record. */
  id?: number
  /** Task id the segment belongs to. */
  taskId: string
  /** Phase type (focus/break). */
  phase: SessionPhase
  /** Milliseconds spent during the segment. */
  duration: number
  /** Timestamp when the segment started. */
  startTime: number
  /** Optional label name snapshot at time of session. */
  labels?: string[]
}

/**
 * SessionSnapshot storage model that includes keys used to calculate stats.
 *
 */
export interface SessionRow extends SessionSnapshot {
  /** YYYY-MM-DD in local (or UTC—pick one and be consistent). */
  dayKey: string
  /** YYYY-Www (ISO week). */
  weekKey: string
}
