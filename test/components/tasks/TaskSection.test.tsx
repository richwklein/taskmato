import { TasksSection } from '@components/tasks'
import { fireEvent, render, screen } from '@testing-library/react'
import { Section } from '@types'
import { describe, expect, it } from 'vitest'

describe('TasksSection', () => {
  const section: Section = {
    id: 'sec1',
    name: 'Untitled Section',
    projectId: 'today',
    order: 10,
  }

  it('renders the section title', () => {
    render(<TasksSection section={section}>Content</TasksSection>)
    expect(screen.getByText('Untitled Section')).toBeInTheDocument()
  })

  it('renders child content inside AccordionDetails', () => {
    render(
      <TasksSection section={section}>
        <div>Task List Content</div>
      </TasksSection>
    )

    expect(screen.getByText('Task List Content')).toBeInTheDocument()
  })

  it('starts expanded by default', () => {
    render(
      <TasksSection section={section}>
        <p>Visible content</p>
      </TasksSection>
    )

    // AccordionDetails content should be visible initially
    expect(screen.getByText('Visible content')).toBeVisible()
  })

  it('toggles expansion when header is clicked', () => {
    render(
      <TasksSection section={section}>
        <p>Hidden content</p>
      </TasksSection>
    )

    const summary = screen.getByRole('button', { expanded: true })
    expect(summary).toBeInTheDocument()

    // Simulate click to collapse
    fireEvent.click(summary)
    expect(summary).toHaveAttribute('aria-expanded', 'false')
  })
})
