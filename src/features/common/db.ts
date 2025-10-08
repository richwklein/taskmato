import type { Label, Project, Section, Setting, Task } from '@types'
import Dexie, { type EntityTable } from 'dexie'

/**
 * The IndexedDB database for the application.
 */
export class TaskmatoDB extends Dexie {
  projects!: EntityTable<Project, 'id'>
  sections!: EntityTable<Section, 'id'>
  tasks!: EntityTable<Task, 'id'>
  labels!: EntityTable<Label, 'id'>
  settings!: EntityTable<Setting, 'key'>

  constructor() {
    super('TaskmatoDB')
    this.version(1).stores({
      projects: 'id, name, color.id, type, parentId, order',
      sections: 'id, name, projectId, order',
      tasks: 'id, priority.id, due, isCompleted, parentId, projectId, sectionId, order, dayOrder',
      labels: 'id, name, color.id, order',
      settings: 'key',
    })
  }
}

export const db = new TaskmatoDB()
