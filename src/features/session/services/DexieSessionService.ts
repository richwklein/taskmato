import { db } from '@common/db'
import { SessionSnapshot } from '@types'

import SessionService, { QueryFilter, Summary } from './SessionService'

export class DexieSessionService implements SessionService {
  /** Indexed label filter; falls back to full scan when no filter. */
  private async query(filter?: QueryFilter): Promise<SessionSnapshot[]> {
    const phase = filter?.phase ?? 'focus'

    // choose best starting index
    if (filter?.label) {
      // multiEntry index on labels
      let coll = db.sessions.where('labels').equals(filter.label)
      if (phase !== '*') coll = coll.and((r) => r.phase === phase)
      if (filter.taskId) coll = coll.and((r) => r.taskId === filter.taskId)
      return coll.toArray()
    }

    if (filter?.taskId) {
      let coll = db.sessions.where('taskId').equals(filter.taskId)
      if (phase !== '*') coll = coll.and((r) => r.phase === phase)
      return coll.toArray()
    }

    if (phase !== '*') {
      return db.sessions.where('phase').equals(phase).toArray()
    }

    return db.sessions.toArray()
  }

  private summarizeRows(rows: SessionSnapshot[]) {
    const count = rows.length
    const total = rows.reduce((a, r) => a + r.duration, 0)
    const average = count ? Math.round(total / count) : 0
    const max = rows.reduce((m, r) => Math.max(m, r.duration), 0)
    return { count, total, average, max }
  }

  async add(snapshot: SessionSnapshot): Promise<void> {
    await db.sessions.add(snapshot)
  }

  async totalForTask(taskId: string): Promise<number> {
    const rows = await this.query({ taskId, phase: 'focus' })
    return rows.reduce((a, r) => a + r.duration, 0)
  }

  async summarize(filter?: QueryFilter) {
    const rows = await this.query(filter)
    return this.summarizeRows(rows)
  }

  async daily(filter?: QueryFilter): Promise<Array<{ date: string } & Summary>> {
    const rows = await this.query(filter)
    const grouped: Record<string, SessionSnapshot[]> = {}
    rows.forEach((r) => {
      const date = new Date(r.startTime)
      const dateKey = date.toISOString().split('T')[0]
      if (!grouped[dateKey]) {
        grouped[dateKey] = []
      }
      grouped[dateKey].push(r)
    })

    return Object.entries(grouped).map(([date, sessions]) => {
      return { date, ...this.summarizeRows(sessions) }
    })
  }

  /** Weekly stats for segments matching the filter (defaults to focus). */
  async weekly(filter?: QueryFilter): Promise<Array<{ week: string } & Summary>> {
    const rows = await this.query(filter)
    const grouped: Record<string, SessionSnapshot[]> = {}
    rows.forEach((r) => {
      const date = new Date(r.startTime)
      const year = date.getUTCFullYear()
      const week = getWeekNumber(date)
      const weekKey = `${year}-W${week.toString().padStart(2, '0')}`
      if (!grouped[weekKey]) {
        grouped[weekKey] = []
      }
      grouped[weekKey].push(r)
    })

    return Object.entries(grouped).map(([week, sessions]) => {
      return { week, ...this.summarizeRows(sessions) }
    })
  }
}

function getWeekNumber(date: Date): number {
  const tempDate = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()))
  const dayNum = tempDate.getUTCDay() || 7
  tempDate.setUTCDate(tempDate.getUTCDate() + 4 - dayNum)
  const yearStart = new Date(Date.UTC(tempDate.getUTCFullYear(), 0, 1))
  return Math.ceil(((tempDate.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
}
