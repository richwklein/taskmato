import { DefaultLayout } from '@common/components/DefaultLayout'
import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

// Mock ToolbarOffset since we only care that it's rendered
vi.mock('@common/components/ToolbarOffset', () => ({
  ToolbarOffset: () => <div data-testid="toolbar-offset" />,
}))

describe('<DefaultLayout />', () => {
  it('renders children content', () => {
    render(
      <DefaultLayout>
        <p>Child content</p>
      </DefaultLayout>
    )

    expect(screen.getByText('Child content')).toBeInTheDocument()
  })

  it('renders the ToolbarOffset component', () => {
    render(
      <DefaultLayout>
        <p>Test</p>
      </DefaultLayout>
    )

    expect(screen.getByTestId('toolbar-offset')).toBeInTheDocument()
  })

  it('applies center alignment styles when center is true', () => {
    render(
      <DefaultLayout center>
        <p>Centered content</p>
      </DefaultLayout>
    )

    const main = screen.getByRole('main')
    const style = window.getComputedStyle(main)

    expect(style.display).toBe('flex')
    expect(style.flexDirection).toBe('column')
    expect(style.textAlign).toBe('center')
  })

  it('applies scroll styles when scroll is true', () => {
    render(
      <DefaultLayout scroll>
        <p>Scrollable content</p>
      </DefaultLayout>
    )

    const main = screen.getByRole('main')
    const style = window.getComputedStyle(main)

    expect(style.overflowY).toBe('auto')
  })

  it('merges custom sx props correctly', () => {
    render(
      <DefaultLayout
        sx={{
          bgcolor: 'red',
          p: 4,
        }}
      >
        <p>Custom styles</p>
      </DefaultLayout>
    )

    const main = screen.getByRole('main')
    const style = window.getComputedStyle(main)

    expect(style.backgroundColor).toBe('rgb(255, 0, 0)')
  })
})
