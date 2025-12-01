import { Label, Project, Section, Task } from '@types'

/** Result returned from a data synchronization operation. */
export type SyncResult = {
  /** Indicates whether the sync completed successfully or failed. */
  status: 'success' | 'error'
  /** Optional error message describing the reason for failure. */
  error?: string
}

/**
 * Defines the contract for interacting with the task management layer.
 *
 * This service acts as the data access and synchronization layer
 * between the Taskmato application and its data source (e.g., Todoist API, local cache).
 */
export interface TasksService {
  /** Returns all {@link Project | projects}, sorted by type then hierarchy (parents before children). */
  getProjects(): Promise<Project[]>

  /** Returns a single {@link Project} by its unique identifier. */
  getProjectById(id: string): Promise<Project | undefined>

  /** Returns all {@link Section | sections} for a project, sorted by order. */
  getSectionsByProjectId(projectId: string): Promise<Section[]>

  /** Returns all {@link Task | tasks} for a project, sorted by dayOrder if "Today" or order otherwise. */
  getTasksByProjectId(projectId: string): Promise<Task[]>

  /** Returns all {@link Label | labels}, sorted by order. */
  getLabels(): Promise<Label[]>

  /** Synchronizes task data with the remote source; may force a full sync. */
  sync(force: boolean): Promise<SyncResult>
}
