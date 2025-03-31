import { Task } from '@types'
import { overdueSectionId, todaySectionId } from '@utils/data' // TODO move these

export function filterTasksBySection(sectionId: string | null, tasks: Task[]): Task[] {
  const now = new Date() // TODO deal with timezones and tasks with a due date without time
  const midnight = new Date()
  midnight.setHours(23, 59, 59, 999)
  const safety = tasks.length > 0 ? tasks[0].projectId : null

  return tasks.filter((task) => {
    console.log(task.dayOrder)
    if (sectionId === todaySectionId) {
      return task.due !== null && task.due >= now && task.due <= midnight
    } else if (sectionId === overdueSectionId) {
      return task.due !== null && task.due < now
    } else {
      if (task.projectId !== safety) {
        throw new Error('Must be called with tasks in the same project.')
      }
      return task.sectionId === sectionId
    }
  })
}

export function sortTasks(tasks: Task[], useDayOrder: boolean = false) {}
