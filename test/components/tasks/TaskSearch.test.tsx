// TaskSearch.test.tsx
import { TaskSearch } from '@components/tasks'
import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

describe('TaskSearch', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.runOnlyPendingTimers()
    vi.useRealTimers()
  })

  it('renders the search input', () => {
    render(<TaskSearch disabled={false} onSearch={vi.fn()} />)
    const input = screen.getByLabelText(/search tasks/i)
    expect(input).toBeInTheDocument()
    expect(input).toHaveAttribute('type', 'text')
  })

  it('respects disabled prop', () => {
    render(<TaskSearch disabled={true} onSearch={vi.fn()} />)
    const input = screen.getByLabelText(/search tasks/i)
    expect(input).toBeDisabled()
  })

  it('debounces calls to onSearch (100ms)', async () => {
    const onSearch = vi.fn()
    render(<TaskSearch disabled={false} onSearch={onSearch} />)

    const input = screen.getByLabelText(/search tasks/i)
    fireEvent.change(input, { target: { value: 'a' } })

    // Not called before debounce interval
    expect(onSearch).not.toHaveBeenCalled()

    await vi.advanceTimersByTimeAsync(100)
    expect(onSearch).toHaveBeenCalledTimes(1)
    expect(onSearch).toHaveBeenCalledExactlyOnceWith('a')
  })

  it('coalesces rapid input changes and calls with the latest value only', async () => {
    const onSearch = vi.fn()
    render(<TaskSearch disabled={false} onSearch={onSearch} />)
    const input = screen.getByLabelText(/search tasks/i)

    fireEvent.change(input, { target: { value: 'a' } })
    await vi.advanceTimersByTimeAsync(50)
    fireEvent.change(input, { target: { value: 'ab' } })
    await vi.advanceTimersByTimeAsync(50)
    fireEvent.change(input, { target: { value: 'abc' } })

    // Still within debounce window; nothing yet
    expect(onSearch).not.toHaveBeenCalled()

    await vi.advanceTimersByTimeAsync(100)

    expect(onSearch).toHaveBeenCalledTimes(1)
    expect(onSearch).toHaveBeenCalledExactlyOnceWith('abc')
  })

  it('cancels pending debounce on unmount (no call after unmount)', async () => {
    const onSearch = vi.fn()
    const { unmount } = render(<TaskSearch disabled={false} onSearch={onSearch} />)
    const input = screen.getByLabelText(/search tasks/i)

    fireEvent.change(input, { target: { value: 'foo' } })
    unmount()

    await vi.advanceTimersByTimeAsync(1000)
    expect(onSearch).not.toHaveBeenCalled()
  })
})
