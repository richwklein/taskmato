import { formatDate, withBase } from '@utils/site'
import { describe, expect, it } from 'vitest'

describe('formatDate', () => {
  it('renders a date-only ISO string as the same calendar day, not one day early', () => {
    // Regression guard: without pinning to UTC, this renders "August 12" west of Greenwich.
    expect(formatDate('2026-08-13')).toBe('August 13, 2026')
  })
})

describe('withBase', () => {
  it('prefixes a leading-slash path with the base URL', () => {
    expect(withBase('/privacy')).toBe('/privacy')
  })

  it('prefixes a bare path with the base URL', () => {
    expect(withBase('privacy')).toBe('/privacy')
  })
})
