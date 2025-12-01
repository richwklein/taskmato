import { Task } from '@types'
import { useCallback, useEffect, useMemo, useReducer } from 'react'

import SessionService from '../services/SessionService'
import { timerReducer } from '../state/timerReducer'
import { SessionContext, SessionContextType } from './SessionContext'

export interface SessionProviderProps {
  /** SessionService instance to store session updates. */
  service: SessionService

  /** React children to be wrapped by the provider. */
  children: React.ReactNode
}

export function SessionProvider({ service, children }: SessionProviderProps) {
  const [state, dispatch] = useReducer(timerReducer, {
    active: undefined,
    isRunning: false,
    focusStreak: 0,
  })

  const start = useCallback((task: Task, ms?: number) => {
    const target = ms ?? 25 * 60 * 1000 // TODO replace with settings
    dispatch({
      type: 'START',
      task,
      phase: 'focus',
      target,
      now: Date.now(),
    })
  }, [])

  const pause = useCallback(() => dispatch({ type: 'PAUSE', now: Date.now() }), [])
  const resume = useCallback(() => dispatch({ type: 'RESUME', now: Date.now() }), [])

  const stop = useCallback(
    async (reason: 'manual' | 'auto' = 'manual') => {
      const snapshot = state.active
      dispatch({ type: 'STOP', now: Date.now(), reason })

      // Persist the segment if there was an active timer.
      if (snapshot) {
        const now = Date.now()
        const elapsed = state.isRunning ? now - snapshot.startTime : 0
        const duration = Math.max(0, Math.min(snapshot.accrued + elapsed, snapshot.target))
        await service.add({
          taskId: snapshot.task.id,
          phase: snapshot.phase,
          duration,
          startTime: snapshot.startTime,
          labels: snapshot.task.labels.map((label) => label.name),
        })
      }
    },
    [service, state.active, state.focusStreak, state.isRunning]
  )

  const switchTask = useCallback((task: Task) => dispatch({ type: 'SWITCH_TASK', task }), [])
  const setTarget = useCallback((ms: number) => dispatch({ type: 'SET_TARGET', target: ms }), [])

  // Auto-stop loop checks remaining time and fires stop('auto') when expired.
  useEffect(() => {
    if (!state.active || !state.isRunning) return

    let raf = 0
    const loop = () => {
      const now = Date.now()
      const { startTime, accrued, target } = state.active!
      const nextAccrued = Math.min(target, accrued + Math.max(0, now - startTime))

      if (nextAccrued >= target) {
        void stop('auto')
        return
      }
      dispatch({ type: 'TICK', now })
      raf = requestAnimationFrame(loop)
    }

    raf = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(raf)
  }, [state.active?.startTime, state.active?.accrued, state.active?.target, state.isRunning, stop])

  const contextValue = useMemo<SessionContextType>(
    () => ({
      isRunning: state.isRunning,
      active: state.active,
      start,
      pause,
      resume,
      stop,
      switchTask,
      setTarget,
    }),
    [state.isRunning, state.active, start, pause, resume, stop, switchTask, setTarget]
  )

  return <SessionContext.Provider value={contextValue}>{children}</SessionContext.Provider>
}
