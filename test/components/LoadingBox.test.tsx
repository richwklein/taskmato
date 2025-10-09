import { LoadingBox } from '@components/LoadingBox'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

describe('LoadingBox', () => {
  it('renders a CircularProgress indicator', () => {
    render(<LoadingBox />)
    const spinner = screen.getByRole('progressbar')
    expect(spinner).toBeInTheDocument()
  })

  it('centers the progress indicator using flexbox', () => {
    const { container } = render(<LoadingBox />)
    const box = container.firstChild as HTMLElement
    const style = window.getComputedStyle(box)

    expect(style.display).toBe('flex')
    expect(style.justifyContent).toBe('center')
    expect(style.alignItems).toBe('center')
  })
})
