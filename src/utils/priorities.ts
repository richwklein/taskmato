import { Priority } from '@types'

import { getColorById } from './colors'

export const priority1: Priority = {
  id: 4,
  name: 'Must Finish',
  color: getColorById('red'),
} as const
export const priority2: Priority = {
  id: 3,
  name: 'Nice to Have',
  color: getColorById('orange'),
} as const
export const priority3: Priority = {
  id: 2,
  name: 'If There is Time',
  color: getColorById('blue'),
} as const
export const priority4: Priority = {
  id: 1,
  name: 'Not Prioritized',
  color: getColorById('charcoal'),
} as const

const priorities = [priority1, priority2, priority3, priority4]

/** Default priority if another priority is not supplied or valid. */
export const defaultPriority: Priority = priority4

/**
 * Get all priorities in descending priority order.
 */
export function getPriorities(): Priority[] {
  return priorities.sort((a, b) => b.id - a.id)
}

/**
 * Get a priority by an id. If the priority is not found, return the default priority.
 */
export function getPriorityById(priorityId: number): Priority {
  const priority = priorities.find((priority) => priority.id === priorityId)
  return priority ?? defaultPriority
}
