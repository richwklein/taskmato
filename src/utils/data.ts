import { Section, Task } from '@types'

/** Id of the today project */
export const todayProjectId = 'today'

/** Id of the today section */
export const todaySectionId = 'today'

/** Id of the overdue section */
export const overdueSectionId = 'overdue'

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
