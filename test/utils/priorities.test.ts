import { defaultPriority, getPriorityById, priority3 } from '@utils/priorities'
import { describe, expect, it } from 'vitest'

describe('getPriorityById', () => {
  it('returns the correct priority when id exists', () => {
    const result = getPriorityById(priority3.id)
    expect(result).toBe(priority3)
  })

  it('returns the default priority when id does not exist', () => {
    const result = getPriorityById(999999)
    expect(result).toBe(defaultPriority)
  })

  it('returns the default priority when id is negative', () => {
    const result = getPriorityById(-1)
    expect(result).toBe(defaultPriority)
  })

  it('returns the default priority when id is null or undefined', () => {
    // @ts-expect-error testing null
    expect(getPriorityById(null)).toBe(defaultPriority)
    // @ts-expect-error testing undefined
    expect(getPriorityById(undefined)).toBe(defaultPriority)
  })
})
