// SidebarToggle.test.tsx
import { SidebarToggle } from '@features/tasks/components/SidebarToggle'
import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

describe('<SidebarToggle />', () => {
  it('persistent + closed: shows "Open Projects Sidebar" and closed icon', () => {
    const onToggle = vi.fn()
    render(<SidebarToggle isPersistent={true} isOpen={false} onToggle={onToggle} />)

    const btn = screen.getByRole('button', { name: 'Open Projects Sidebar' })
    expect(btn).toBeInTheDocument()
    expect(btn).toHaveAttribute('title', 'Open Projects Sidebar')
    expect(btn).toHaveAttribute('aria-expanded', 'false')

    expect(screen.getByTestId('MenuIcon')).toBeInTheDocument()
  })

  it('persistent + open: shows "Close Projects Sidebar" and open icon', () => {
    const onToggle = vi.fn()
    render(<SidebarToggle isPersistent={true} isOpen={true} onToggle={onToggle} />)

    const btn = screen.getByRole('button', { name: 'Close Projects Sidebar' })
    expect(btn).toBeInTheDocument()
    expect(btn).toHaveAttribute('title', 'Close Projects Sidebar')
    expect(btn).toHaveAttribute('aria-expanded', 'true')

    expect(screen.getByTestId('MenuOpenIcon')).toBeInTheDocument()
  })

  it('temporary: always shows "Show Project Sidebar" label', () => {
    const onToggle = vi.fn()
    // Try both open/closed to ensure label is independent of isOpen on mobile
    const { rerender } = render(
      <SidebarToggle isPersistent={false} isOpen={false} onToggle={onToggle} />
    )

    let btn = screen.getByRole('button', { name: 'Show Project Sidebar' })
    expect(btn).toBeInTheDocument()
    expect(btn).toHaveAttribute('title', 'Show Project Sidebar')
    expect(btn).toHaveAttribute('aria-expanded', 'false')

    rerender(<SidebarToggle isPersistent={false} isOpen={true} onToggle={onToggle} />)
    btn = screen.getByRole('button', { name: 'Show Project Sidebar' })
    expect(btn).toBeInTheDocument()
    expect(btn).toHaveAttribute('aria-expanded', 'true')
  })

  it('invokes onToggle when clicked', () => {
    const onToggle = vi.fn()
    render(<SidebarToggle isPersistent={true} isOpen={false} onToggle={onToggle} />)

    const btn = screen.getByRole('button', { name: 'Open Projects Sidebar' })
    fireEvent.click(btn)
    expect(onToggle).toHaveBeenCalledTimes(1)
  })
})
