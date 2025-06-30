import { Label, Project, ProjectType, Section, SyncData, Task } from '@types'
import { getColorById } from '@utils/colors'
import { getPriorityById } from '@utils/priorities'
import axios from 'axios'

const SYNC_API_URL = 'https://api.todoist.com/sync/v9/sync'
const FULL_SYNC_TOKEN = '*'
const RESOURCE_TYPES = ['projects', 'sections', 'items', 'labels', 'day_orders']

interface ISyncService {
  setKey(key: string): void
  sync(data: SyncData): Promise<SyncData>
}

/**
 * SyncService
 *
 * The sync service is a singleton used to sync task related data back and
 * forth with todoist.
 */
export class SyncService implements ISyncService {
  private static instance: SyncService
  private key: string

  constructor(key: string) {
    // TODO get apiKey from settings
    this.key = key
  }

  /**
   * Gets the singleton instance of the SyncService.
   * @returns The singleton instance of the SyncService.
   */
  public static getInstance(): SyncService {
    if (!SyncService.instance) {
      SyncService.instance = new SyncService(localStorage.getItem('todoistApiKey') || '')
    }
    return SyncService.instance
  }

  /**
   * Sets the API key for the SyncService.
   *
   * @param key - The API key to set.
   */
  setKey(key: string): void {
    this.key = key
  }

  /**
   * Synchronize the todoist data.
   *
   * This will retrieve partial or full data from Todoist and then merge the
   * data with the existing passed in data.
   *
   * @param data - The existing synced data.
   * @returns the merged data.
   */
  async sync(data: SyncData): Promise<SyncData> {
    if (this.key === '') {
      return {
        token: null,
        projects: new Map(),
        sections: new Map(),
        tasks: new Map(),
        labels: new Map(),
      }
    }

    const syncToken = data.token ?? FULL_SYNC_TOKEN

    try {
      const response = await axios.post(
        SYNC_API_URL,
        {
          sync_token: syncToken,
          resource_types: JSON.stringify(RESOURCE_TYPES),
        },
        {
          headers: {
            Authorization: `Bearer ${this.key}`,
          },
        }
      )

      const labels = buildLabels(data.labels, response.data.labels)
      console.log(response.data)
      return {
        token: response.data.sync_token,
        projects: buildProjects(data.projects, response.data.projects),
        sections: buildSections(data.sections, response.data.sections),
        tasks: buildTasks(data.tasks, response.data.items, labels),
        labels: labels,
      }
    } catch (error) {
      console.error(`Failed to fetch data`, error)
      throw error
    }
  }
}

const buildProjects = (
  projects: Map<string, Project>,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  synced: Record<string, any>[]
): Map<string, Project> => {
  const results = new Map<string, Project>(projects)

  synced.forEach((value) => {
    if (results.has(value.id) && (value.is_archived || value.is_deleted)) {
      results.delete(value.id)
    }

    results.set(value.id, {
      id: value.id,
      name: value.name,
      color: getColorById(value.color),
      type: value.name == 'Inbox' ? ProjectType.Inbox : ProjectType.Project,
      parentId: value.parent_id,
      order: value.child_order,
    })
  })

  return results
}

const buildSections = (
  sections: Map<string, Section>,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  synced: Record<string, any>[]
): Map<string, Section> => {
  const results = new Map<string, Section>(sections)

  synced.forEach((value) => {
    if (results.has(value.id) && (value.is_archived || value.is_deleted)) {
      results.delete(value.id)
    }

    results.set(value.id, {
      id: value.id,
      name: value.name,
      projectId: value.project_id,
      order: value.section_order,
    })
  })

  return results
}

const buildTasks = (
  tasks: Map<string, Task>,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  synced: Record<string, any>[],
  labels: Map<string, Label>
): Map<string, Task> => {
  const results = new Map<string, Task>(tasks)

  synced.forEach((value) => {
    if (results.has(value.id) && (value.checked || value.is_deleted)) {
      results.delete(value.id)
    }

    results.set(value.id, {
      id: value.id,
      priority: getPriorityById(value.priority),
      content: value.content,
      description: value.description,
      labels: getLabelsByIds(value.labels, labels),
      due: value.due?.date ? new Date(value.due.date) : null,
      deadline: value.deadline?.date ? new Date(value.deadline.date) : null,
      isCompleted: value.checked,
      parentId: value.parent_id,
      projectId: value.project_id,
      sectionId: value.section_id,
      order: value.child_order,
      dayOrder: value.day_order,
    })
  })

  return results
}

const getLabelsByIds = (labelIds: string[], labelsMap: Map<string, Label>): Label[] => {
  // Retrieve the labels from the map using the list of IDs
  const labels = labelIds
    .map((id) => labelsMap.get(id))
    .filter((label) => label !== undefined) as Label[]

  // Sort the labels by their order property
  labels.sort((a, b) => a.order - b.order)

  return labels
}

const buildLabels = (
  labels: Map<string, Label>,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  synced: Record<string, any>[]
): Map<string, Label> => {
  const results = new Map<string, Label>(labels)

  synced.forEach((value) => {
    if (results.has(value.id) && value.is_deleted) {
      results.delete(value.id)
    }

    results.set(value.id, {
      id: value.id,
      name: value.name,
      color: getColorById(value.color),
      order: value.item_order,
    })
  })

  return results
}

export default SyncService.getInstance()
