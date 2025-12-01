import { Task } from '@types'
import { createContext } from 'react'

import { ActiveRun } from '../types'

export interface SessionContextType {
  /** True when a session exists and is ticking. */
  isRunning: boolean

  /** Active timer data, if any. */
  active?: ActiveRun

  /** Start a focus session for a task; optional custom duration. */
  start: (task: Task, ms?: number) => void

  /** Pause the timer if active. */
  pause: () => void

  /** Resume the timer if paused. */
  resume: () => void

  /** Stop the timer and persist a session record. */
  stop: (reason?: 'manual' | 'auto') => Promise<void>

  /** Swap the task on the fly without stopping. */
  switchTask: (task: Task) => void

  /** Override the current target duration. */
  setTarget: (ms: number) => void

  /** Config used by the provider. */
  // TODO config: PomodoroConfig
}

export const SessionContext = createContext<SessionContextType | null>(null)
