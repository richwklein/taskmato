import type { Label, Project, Section, SessionSnapshot, Setting, Task } from '@types'
import Dexie, { type EntityTable } from 'dexie'

/**
 * TaskmatoDB — Dexie wrapper around the app’s IndexedDB schema.
 * Defines the database version and object stores.
 */
export class TaskmatoDB extends Dexie {
  projects!: EntityTable<Project, 'id'>
  sections!: EntityTable<Section, 'id'>
  tasks!: EntityTable<Task, 'id'>
  labels!: EntityTable<Label, 'id'>
  settings!: EntityTable<Setting, 'key'>
  sessions!: EntityTable<SessionSnapshot, 'id'>

  constructor() {
    super('TaskmatoDB')
    this.version(1).stores({
      projects: 'id, name, color.id, type, parentId, order',
      sections: 'id, name, projectId, order',
      tasks: 'id, priority.id, due, isCompleted, parentId, projectId, sectionId, order, dayOrder',
      labels: 'id, name, color.id, order',
      settings: 'key',
      sessions: '++id, taskId, phase, startTime, *labels',
    })
  }
}

export const db = new TaskmatoDB()
