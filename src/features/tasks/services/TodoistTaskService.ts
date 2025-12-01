import { db } from '@common/db'
import { SettingsService } from '@features/settings/services/SettingsService'
import { type Label, type Project, PROJECT_TYPE, type Section, type Task } from '@types'
import axios from 'axios'
import Dexie from 'dexie'

import { defaultColor, getColorById } from '../model/colors'
import { getPriorityById } from '../model/priorities'
import { SyncResult, TasksService } from './TasksService'

/** Id of the today project */
export const todayProjectId = 'today'

const SYNC_API_URL = 'https://api.todoist.com/sync/v9/sync'
const FULL_SYNC_TOKEN = '*'
const RESOURCE_TYPES = ['projects', 'sections', 'items', 'labels', 'day_orders']

export class TodoistTasksService implements TasksService {
  private settings: SettingsService

  constructor(settings: SettingsService) {
    this.settings = settings
  }

  async getProjects(): Promise<Project[]> {
    const order = ['today', 'inbox', 'project'] as const

    const projects = (await db.projects.orderBy('type').toArray()).reduce((map, project) => {
      map.set(project.id, project)
      return map
    }, new Map<string, Project>())
    const temp = new Map<string, Project>(projects)
    temp.set(todayProjectId, {
      id: todayProjectId,
      name: 'Today',
      color: defaultColor,
      type: PROJECT_TYPE.Today,
      parentId: null,
      order: 0,
    } as Project)

    const sorted = Array.from(temp.values()).sort((a, b) => {
      return a.type !== b.type ? order.indexOf(a.type) - order.indexOf(b.type) : a.order - b.order
    })

    const buildHierarchy = (parentId: string | null): Project[] => {
      return sorted
        .filter((project) => project.parentId === parentId)
        .flatMap((project) => [project, ...buildHierarchy(project.id)])
    }

    return buildHierarchy(null)
  }

  async getProjectById(id: string): Promise<Project | undefined> {
    return db.projects.get(id)
  }

  async getSectionsByProjectId(projectId: string): Promise<Section[]> {
    // TODO add the special today sections

    return await db.sections.where('projectId').equals(projectId).sortBy('order')
  }

  async getTasksByProjectId(projectId: string): Promise<Task[]> {
    const sort = projectId == todayProjectId ? 'dayOrder' : 'order'
    return db.tasks.where('projectId').equals(projectId).sortBy(sort)
  }

  async getLabels(): Promise<Label[]> {
    return await db.labels.orderBy('order').toArray()
  }

  async sync(force: boolean): Promise<SyncResult> {
    const apiKey = await this.settings.get('todoist.api.key')
    if (!apiKey) {
      return { status: 'error', error: 'API key not set' }
    }

    let token = await this.settings.get('todoist.sync.token')
    if (force || !token) {
      token = FULL_SYNC_TOKEN
      await clearTables()
    }

    try {
      const response = await axios.post(
        SYNC_API_URL,
        {
          sync_token: token,
          resource_types: JSON.stringify(RESOURCE_TYPES),
        },
        {
          headers: {
            Authorization: `Bearer ${apiKey}`,
          },
        }
      )

      await this.settings.set('todoist.sync.token', response.data.sync_token as string)

      await updateTable(db.labels, response.data.labels, (record) => ({
        id: record.id,
        name: record.name,
        color: getColorById(record.color),
        order: record.item_order,
      }))

      const labelsMap = (await this.getLabels()).reduce((map, label) => {
        map.set(label.name, label)
        return map
      }, new Map<string, Label>())

      console.info(
        '[TodoistTasksService] Synced labels:',
        Array.from(labelsMap.values())
          .map((label) => label.name)
          .join(', ')
      )

      await Promise.all([
        updateTable(db.projects, response.data.projects, (record) => ({
          id: record.id,
          name: record.name,
          color: getColorById(record.color),
          type: record.name == 'Inbox' ? PROJECT_TYPE.Inbox : PROJECT_TYPE.Project,
          parentId: record.parent_id,
          order: record.child_order,
        })),

        updateTable(db.sections, response.data.sections, (record) => ({
          id: record.id,
          name: record.name,
          projectId: record.project_id,
          order: record.section_order,
        })),

        updateTable(db.tasks, response.data.items, (record) => ({
          id: record.id,
          priority: getPriorityById(record.priority),
          content: record.content,
          description: record.description,
          labels: getLabelsByName(record.labels, labelsMap),
          due: record.due?.date ? new Date(record.due.date) : null,
          isCompleted: record.checked,
          parentId: record.parent_id,
          projectId: record.project_id,
          sectionId: record.section_id,
          order: record.child_order,
          dayOrder: record.day_order,
        })),
      ])
    } catch (error) {
      return { status: 'error', error: (error as Error).message }
    }

    return { status: 'success' }
  }
}

/**
 * Get the list of {@link Label | labels} from a list of label IDs.
 * @param labelIds - list of label IDs
 * @param labelsMap - map of existing labels
 * @returns A list of labels
 */
function getLabelsByName(labelNames: string[], labels: Map<string, Label>): Label[] {
  const found = labelNames.map((name) => labels.get(name)) as Label[]

  found.sort((a, b) => a.order - b.order)
  return found
}

/**
 * Generic function for updating a table in the database.
 * @param table - The Dexie table to update.
 * @param records - The records to merge into the table.
 * @param mapper - A function that maps the raw record to the desired type.
 */
/**
 * Generic function for updating a table in the database.
 * @param table - The Dexie table to update.
 * @param records - The records to merge into the table.
 * @param mapper - A function that maps the raw record to the desired type.
 */
async function updateTable<T>(
  table: Dexie.Table<T, string>,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  records: Record<string, any>[],
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  mapper: (record: Record<string, any>) => T
): Promise<Set<T>> {
  const removed = new Set<string>()
  const remaining = new Set<T>()

  records.forEach((value) => {
    if ('is_archived' in value && value.is_archived) {
      removed.add(value.id as string)
    } else if ('is_deleted' in value && value.is_deleted) {
      removed.add(value.id as string)
    } else {
      remaining.add(mapper(value))
    }
  })

  if (removed.size > 0) {
    await table.bulkDelete(Array.from(removed))
  }
  if (remaining.size > 0) {
    await table.bulkPut(Array.from(remaining))
  }

  return remaining
}

/**
 * Clear all the task related data from the database.
 */
async function clearTables() {
  await Promise.all([db.projects.clear(), db.sections.clear(), db.tasks.clear(), db.labels.clear()])
}
