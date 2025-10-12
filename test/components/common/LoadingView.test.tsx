import { LoadingView } from '@components/common'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

describe('LoadingView', () => {
  it('renders a CircularProgress indicator', () => {
    render(<LoadingView />)
    const spinner = screen.getByRole('progressbar')
    expect(spinner).toBeInTheDocument()
  })

  it('centers the progress indicator using flexbox', () => {
    const { container } = render(<LoadingView />)
    const box = container.firstChild as HTMLElement
    const style = window.getComputedStyle(box)

    expect(style.display).toBe('flex')
    expect(style.justifyContent).toBe('center')
    expect(style.alignItems).toBe('center')
  })
})
