import { Task } from '@types'
import { useCallback } from 'react'

import { useSessionContext } from './useSessionContext'

export interface StartOptions {
  /** Custom duration in ms; defaults to config focusMs when omitted. */
  duration?: number
}

/** Small hook to start a session directly from a TaskCard click. */
export function useStartSessionFromTask() {
  const { start } = useSessionContext()
  return useCallback((task: Task, opts?: StartOptions) => start(task, opts?.duration), [start])
}
