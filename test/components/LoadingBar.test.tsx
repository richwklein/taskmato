import { LoadingBar } from '@components/LoadingBar'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

describe('LoadingBar', () => {
  it('renders a LinearProgress in indeterminate mode when loading', () => {
    render(<LoadingBar isLoading={true} />)

    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
    expect(progress).not.toHaveAttribute('aria-valuenow')

    const style = window.getComputedStyle(progress)
    expect(style.opacity).toBe('1')
  })

  it('renders a LinearProgress in determinate mode with value 0 when not loading', () => {
    render(<LoadingBar isLoading={false} />)

    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
    expect(progress).toHaveAttribute('aria-valuenow', '0')

    const style = window.getComputedStyle(progress)
    expect(style.opacity).toBe('0')
  })

  it('applies consistent height', () => {
    render(<LoadingBar isLoading={true} />)
    const progress = screen.getByRole('progressbar')

    const style = window.getComputedStyle(progress)
    expect(style.height).toBe('4px')
  })
})
