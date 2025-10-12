// SidebarNavigation.test.tsx
import { SidebarNavigation } from '@components/tasks'
import { createTheme, ThemeProvider } from '@mui/material'
import { fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { fakeProjects } from '../../fakeData'

describe('SidebarNavigation (Drawer-based)', () => {
  const onSelect = vi.fn()
  const onClosing = vi.fn()
  const onClosed = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  function renderWithTheme(ui: React.ReactElement, theme = createTheme()) {
    return {
      theme,
      ...render(<ThemeProvider theme={theme}>{ui}</ThemeProvider>),
    }
  }

  function renderDesktop(open = true, selectedId?: string) {
    return render(
      <SidebarNavigation
        projects={fakeProjects}
        selectedId={selectedId}
        onSelect={onSelect}
        isDesktop={true}
        isOpen={open}
        onClosing={onClosing}
        onClosed={onClosed}
      />
    )
  }

  function renderMobile(open = true, selectedId?: string) {
    return render(
      <SidebarNavigation
        projects={fakeProjects}
        selectedId={selectedId}
        onSelect={onSelect}
        isDesktop={false}
        isOpen={open}
        onClosing={onClosing}
        onClosed={onClosed}
      />
    )
  }

  it('renders all project items and a divider before the first "Project" type', () => {
    renderDesktop(true)

    fakeProjects.forEach((p) => {
      expect(screen.getByRole('button', { name: new RegExp(p.name, 'i') })).toBeInTheDocument()
    })

    const separators = screen.getAllByRole('separator')
    expect(separators.length).toBeGreaterThanOrEqual(1)
  })

  it('highlights the selected project (aria-selected=true)', () => {
    renderDesktop(true, 'inbox')

    const selected = screen.getByRole('button', { name: /inbox/i })
    expect(selected).toHaveAttribute('aria-selected', 'true')

    const notSelected = screen.getByRole('button', { name: /today/i })
    expect(notSelected).not.toHaveAttribute('aria-selected', 'true')
  })

  it('calls onSelect with the project id when an item is clicked', () => {
    renderDesktop(true)

    const todayBtn = screen.getByRole('button', { name: /today/i })
    fireEvent.click(todayBtn)

    expect(onSelect).toHaveBeenCalledTimes(1)
    expect(onSelect).toHaveBeenCalledExactlyOnceWith('today')
  })

  it('desktop (persistent) drawer does not render a backdrop', () => {
    renderDesktop(true)
    const backdrop = document.querySelector('.MuiBackdrop-root') as HTMLElement
    expect(backdrop).toBeNull()
  })

  it('mobile (temporary) drawer render a backdrop', () => {
    renderMobile(true)
    const backdrop = document.querySelector('.MuiBackdrop-root') as HTMLElement
    expect(backdrop).not.toBeNull()
  })

  it('invokes onClosing at the start of the close', () => {
    renderMobile(true)

    const backdrop = document.querySelector('.MuiBackdrop-root') as HTMLElement
    expect(backdrop).not.toBeNull()

    fireEvent.mouseDown(backdrop)
    fireEvent.click(backdrop)

    expect(onClosing).toHaveBeenCalledTimes(1)
  })

  it('invokes onClosed after transition end', () => {
    const { container } = renderDesktop(true)

    const paper = container.querySelector('.MuiDrawer-paper')
    expect(paper).not.toBeNull()

    if (paper) {
      fireEvent.transitionEnd(paper)
    }

    expect(onClosed).toHaveBeenCalledTimes(1)
  })

  it('applies pl=4 (theme.spacing(4)) for child projects and pl=2 for top-level', () => {
    const { theme } = renderWithTheme(
      <SidebarNavigation
        projects={fakeProjects}
        selectedId={'p1'}
        onSelect={onSelect}
        isDesktop={true}
        isOpen={true}
        onClosing={onClosing}
        onClosed={onClosed}
      />
    )

    // Top-level item
    const parentBtn = screen.getByRole('button', { name: /work/i })
    const parentStyle = window.getComputedStyle(parentBtn)
    expect(parentStyle.paddingLeft).toBe(theme.spacing(2))

    // Child item
    const childBtn = screen.getByRole('button', { name: /sdlc/i })
    const childStyle = window.getComputedStyle(childBtn)
    expect(childStyle.paddingLeft).toBe(theme.spacing(4))
  })
})
