// RefreshButton.test.tsx
import { RefreshButton } from '@components/tasks'
import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

describe('RefreshButton', () => {
  it('renders the button', () => {
    render(<RefreshButton disabled={false} onRefresh={vi.fn()} onHardRefresh={vi.fn()} />)
    const btn = screen.getByRole('button', { name: /refresh/i })
    expect(btn).toBeInTheDocument()
  })

  it('calls onRefresh on normal click', () => {
    const onRefresh = vi.fn()
    const onHardRefresh = vi.fn()
    render(<RefreshButton disabled={false} onRefresh={onRefresh} onHardRefresh={onHardRefresh} />)

    fireEvent.click(screen.getByRole('button', { name: /refresh/i }))
    expect(onRefresh).toHaveBeenCalledTimes(1)
    expect(onHardRefresh).not.toHaveBeenCalled()
  })

  it('calls onHardRefresh on Shift+click', () => {
    const onRefresh = vi.fn()
    const onHardRefresh = vi.fn()
    render(<RefreshButton disabled={false} onRefresh={onRefresh} onHardRefresh={onHardRefresh} />)

    fireEvent.click(screen.getByRole('button', { name: /refresh/i }), { shiftKey: true })
    expect(onHardRefresh).toHaveBeenCalledTimes(1)
    expect(onRefresh).not.toHaveBeenCalled()
  })

  it('respects disabled state', () => {
    const onRefresh = vi.fn()
    const onHardRefresh = vi.fn()
    render(<RefreshButton disabled onRefresh={onRefresh} onHardRefresh={onHardRefresh} />)

    const btn = screen.getByRole('button', { name: /refresh/i })
    expect(btn).toBeDisabled()

    fireEvent.click(btn)
    fireEvent.click(btn, { shiftKey: true })

    expect(onRefresh).not.toHaveBeenCalled()
    expect(onHardRefresh).not.toHaveBeenCalled()
  })
})
