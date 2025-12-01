import { SessionPhase, SessionSnapshot } from '../types'

/** Summary stats for segments (focus-only by default). */
export interface Summary {
  count: number
  total: number
  average: number
  max: number
}

export interface QueryFilter {
  /** Optional label to filter by. */
  label?: string
  /** Optional task to filter by. */
  taskId?: string
  /** Phase filter; defaults to 'focus'. Use '*' for all phases. */
  phase?: SessionPhase | '*'
}

/**
 * Contract used by the context to persist and query sessions.
 * Uses IndexedDB (via `db.sessions`) for persistence and supports
 */
export interface SessionService {
  /** Append a completed session segment to storage. */
  add(snapshot: SessionSnapshot): Promise<void>

  /** Sum all focus durations for a task. */
  totalForTask(taskId: string): Promise<number>

  /** Summary for segments matching the filter (defaults to focus). */
  summarize(filter?: QueryFilter): Promise<Summary>

  /** Daily stats for segments matching the filter (defaults to focus). */
  daily(filter?: QueryFilter): Promise<Array<{ date: string } & Summary>>

  /** Weekly stats for segments matching the filter (defaults to focus). */
  weekly(filter?: QueryFilter): Promise<Array<{ week: string } & Summary>>
}

export default SessionService
