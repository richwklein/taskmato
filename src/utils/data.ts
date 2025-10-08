import { Project, ProjectType, Section, Task } from '@types'
import { defaultColor } from '@utils/colors'

/** Id of the today project */
export const todayProjectId = 'today'

/** Id of the today section */
export const todaySectionId = 'today'

/** Id of the overdue section */
export const overdueSectionId = 'overdue'

/**
 * get a list of projects.
 *
 * This function adds the special Today and Inbox projects if they do not exist
 * and then sorts the projects by order within a parent project.
 *
 * @param projects - The map of projects to use in creating the list.
 * @returns the sorted an updated list of projects.
 */
export function getProjects(projects: Map<string, Project>): Project[] {
  const temp = new Map<string, Project>(projects)
  temp.set(todayProjectId, {
    id: todayProjectId,
    name: 'Today',
    color: defaultColor,
    type: ProjectType.Today,
    parentId: null,
    order: 0,
  })

  const sorted = Array.from(temp.values()).sort((a, b) => {
    return a.type !== b.type ? a.type - b.type : a.order - b.order
  })

  const buildHierarchy = (parentId: string | null): Project[] => {
    return sorted
      .filter((project) => project.parentId === parentId)
      .flatMap((project) => [project, ...buildHierarchy(project.id)])
  }

  return buildHierarchy(null)
}

/**
 * get all sections for the given projectId.
 *
 * This will create sections for the special today project and then sorts the
 * sections in order.
 *
 * @param projectId - The id of the project to filter the sections by.
 * @param sections - The map of sections to build the list from.
 * @returns The updated and sorted list of sections.
 */
export function getSectionsByProjectId(
  projectId: string,
  sections: Map<string, Section>
): Section[] {
  const results = Array.from(sections.values()).filter((section) => section.projectId == projectId)

  // add the special today sections
  if (projectId == todayProjectId) {
    results.push(
      { id: todaySectionId, name: 'Today', projectId: projectId, order: -100 },
      { id: overdueSectionId, name: 'Overdue', projectId: projectId, order: -90 }
    )
  }

  // return the sorted sections can be empty
  return results.sort((a, b) => a.order - b.order)
}

export function getTasksByProjectId(projectId: string, tasks: Map<string, Task>): Task[] {
  if (projectId == todayProjectId) {
    return getTodayTasks(tasks)
  }

  const results = Array.from(tasks.values()).filter((task) => task.projectId == projectId)
  return results
}

export function getTodayTasks(tasks: Map<string, Task>): Task[] {
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  const results = Array.from(tasks.values()).filter((task) => {
    if (!task.due) return false
    const dueDate = new Date(task.due)
    dueDate.setHours(0, 0, 0, 0)
    return dueDate <= today
  })

  return results
}
