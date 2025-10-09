import { colors, defaultColor, getColorById } from '@utils/colors'
import { describe, expect, it } from 'vitest'

describe('getColorById', () => {
  it('returns the correct color when id exists', () => {
    const target = colors[0]
    const result = getColorById(target.id)
    expect(result).toBe(target)
  })

  it('returns the default color when id does not exist', () => {
    const result = getColorById('nonexistent-id')
    expect(result).toBe(defaultColor)
  })

  it('returns the default color when id is empty string', () => {
    const result = getColorById('')
    expect(result).toBe(defaultColor)
  })

  it('returns the default color when id is null or undefined', () => {
    // @ts-expect-error testing null
    expect(getColorById(null)).toBe(defaultColor)
    // @ts-expect-error testing undefined
    expect(getColorById(undefined)).toBe(defaultColor)
  })

  it('is case insensitive when matching ids', () => {
    const color = colors[1]
    const result = getColorById(color.id.toUpperCase())
    expect(result).toBe(color)
  })
})
