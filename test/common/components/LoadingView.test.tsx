import type { DefaultLayoutProps } from '@common/components/DefaultLayout'
import { LoadingView } from '@common/components/LoadingView'
import { render, screen } from '@testing-library/react'
import { act, cleanup } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

// Mock DefaultLayout so we don’t test layout internals
vi.mock('@common/components/DefaultLayout', () => ({
  DefaultLayout: ({ children }: DefaultLayoutProps) => (
    <div data-testid="default-layout">{children}</div>
  ),
}))

describe('LoadingView', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    cleanup()
    vi.runOnlyPendingTimers()
    vi.useRealTimers()
  })

  it('does not render immediately (before delay)', () => {
    render(<LoadingView delay={500} />)
    expect(screen.queryByTestId('default-layout')).not.toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  it('renders spinner and default message after delay', () => {
    render(<LoadingView delay={250} />)

    act(() => {
      vi.advanceTimersByTime(250)
    })

    expect(screen.getByRole('progressbar')).toBeInTheDocument()
    expect(screen.getByText('Loading...')).toBeInTheDocument()
    expect(screen.getByTestId('default-layout')).toBeInTheDocument()
  })

  it('renders custom message', () => {
    render(<LoadingView message="Fetching data..." delay={0} />)

    act(() => {
      vi.advanceTimersByTime(0)
    })

    expect(screen.getByText('Fetching data...')).toBeInTheDocument()
  })

  it('cleans up timer on unmount', () => {
    const clearSpy = vi.spyOn(global, 'clearTimeout')
    const { unmount } = render(<LoadingView delay={1000} />)

    unmount()
    expect(clearSpy).toHaveBeenCalled()
  })
})
