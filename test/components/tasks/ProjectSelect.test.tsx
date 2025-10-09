import { ProjectSelect } from '@components/tasks'
import { fireEvent, render, screen, within } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { fakeProjects } from '../../fakeData'

describe('ProjectSelect', () => {
  const onSelect = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders a select input with all project options', async () => {
    render(<ProjectSelect disabled={false} projects={fakeProjects} onSelect={onSelect} />)

    const combobox = screen.getByRole('combobox', { name: /project/i })
    expect(combobox).toBeInTheDocument()

    fireEvent.mouseDown(combobox)
    expect(await screen.findAllByRole('option')).toHaveLength(4)
  })

  it('calls onSelect when a project is chosen', async () => {
    render(<ProjectSelect disabled={false} projects={fakeProjects} onSelect={onSelect} />)

    const combobox = screen.getByRole('combobox', { name: /project/i })
    fireEvent.mouseDown(combobox)

    const option = await screen.findByRole('option', { name: /today/i })
    fireEvent.click(option)

    expect(onSelect).toHaveBeenCalledExactlyOnceWith('today')
  })

  it('renders the selected project when selectedId is valid', () => {
    render(
      <ProjectSelect
        disabled={false}
        projects={fakeProjects}
        selectedId="inbox"
        onSelect={onSelect}
      />
    )

    const combobox = screen.getByRole('combobox', { name: /project/i })
    within(combobox).getByRole('img', { name: /inbox/i })
    const els = within(combobox).getAllByText(/inbox/i)
    const visibleLabel = els.find((el) => !el.closest('svg'))
    expect(visibleLabel).toBeInTheDocument()
  })

  it('renders empty selection when selectedId is not in project list', () => {
    render(
      <ProjectSelect
        disabled={false}
        projects={fakeProjects}
        selectedId="invalid-id"
        onSelect={onSelect}
      />
    )

    const combobox = screen.getByRole('combobox', { name: /project/i })
    expect(within(combobox).getByLabelText(/no project selected/i)).toBeInTheDocument()
  })

  it('disables the select when disable prop is true', () => {
    render(<ProjectSelect disabled={true} projects={fakeProjects} onSelect={onSelect} />)

    const combobox = screen.getByRole('combobox', { name: /project/i })
    expect(combobox).toHaveAttribute('aria-disabled', 'true')
    expect(combobox).toHaveClass('Mui-disabled')

    fireEvent.mouseDown(combobox)
    expect(screen.queryByRole('option')).not.toBeInTheDocument()
    expect(onSelect).not.toHaveBeenCalled()
  })
})
