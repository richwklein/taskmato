import { Task } from '@types'

import { ActiveRun, SessionPhase, SessionSnapshot } from '../types'

/** Live state for the Pomodoro timer. */
export interface TimerState {
  /** In-progress run, if any. */
  active?: ActiveRun
  /** True if the timer is currently ticking. */
  isRunning: boolean
  /** Completed focus sessions since the last long break. */
  focusStreak: number
}

type TimerAction =
  | {
      type: 'START'
      task: Task
      phase: SessionPhase
      target: number
      now: number
    }
  | { type: 'PAUSE'; now: number }
  | { type: 'RESUME'; now: number }
  | { type: 'STOP'; now: number; reason: 'manual' | 'auto' }
  | { type: 'SWITCH_TASK'; task: Task }
  | { type: 'SET_TARGET'; target: number }
  | { type: 'TICK'; now: number }
  | { type: 'RESET' }

/** Pure reducer for timer state transitions. */
export function timerReducer(state: TimerState, action: TimerAction): TimerState {
  switch (action.type) {
    case 'START': {
      const active: ActiveRun = {
        phase: action.phase,
        startTime: Date.now(),
        accrued: 0,
        target: action.target,
        task: action.task,
      }
      return {
        ...state,
        active,
        isRunning: true,
      }
    }

    case 'PAUSE': {
      if (!state.active) return state
      const elapsed = action.now - state.active.startTime
      const accrued = Math.min(state.active.target, state.active.accrued + elapsed)
      return {
        ...state,
        isRunning: false,
        active: { ...state.active, accrued, startTime: action.now },
      }
    }

    case 'RESUME': {
      if (!state.active) return state
      const active = { ...state.active, startTime: action.now }
      return { ...state, active, isRunning: true }
    }

    case 'STOP': {
      if (!state.active) return { ...state, isRunning: false }
      const elapsed = state.isRunning ? action.now - state.active.startTime : 0
      const total = state.active.accrued + elapsed

      const snapshot: SessionSnapshot = {
        taskId: state.active.task.id,
        phase: state.active.phase,
        duration: Math.max(0, Math.min(total, state.active.target)),
        startTime: state.active.startTime,
        labels: state.active.task.labels.map((label) => label.name),
      }

      // focusStreak only increments for full focus completions
      const focusStreak =
        state.active.phase === 'focus' && snapshot.duration >= state.active.target
          ? state.focusStreak + 1
          : state.focusStreak

      return { active: undefined, isRunning: false, focusStreak }
    }

    case 'SWITCH_TASK': {
      if (!state.active) return state
      return {
        ...state,
        active: {
          ...state.active,
          task: action.task,
        },
      }
    }

    case 'SET_TARGET': {
      if (!state.active) return state
      return {
        ...state,
        active: { ...state.active, target: action.target },
      }
    }

    case 'TICK': {
      if (!state.active || !state.isRunning) return state

      const elapsed = action.now - state.active.startTime
      if (elapsed == 0) return state

      const accrued = Math.min(state.active.target, state.active.accrued + elapsed)
      if (accrued === state.active.accrued) return state

      return { ...state, active: { ...state.active, accrued, startTime: action.now } }
    }

    case 'RESET':
      return {
        active: undefined,
        isRunning: false,
        focusStreak: 0,
      }

    default:
      return state
  }
}
