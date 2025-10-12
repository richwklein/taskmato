import { ProjectIcon } from '@components/tasks'
import { render, screen } from '@testing-library/react'
import { ProjectType } from '@types'
import { describe, expect, it } from 'vitest'

describe('ProjectIcon', () => {
  it.todo('Stop using internal test ids')

  it('renders TodayIcon when type is Today', () => {
    render(<ProjectIcon type={ProjectType.Today} />)
    const svg = screen.getByTestId('TodayIcon')
    expect(svg).toBeInTheDocument()
  })

  it('renders InboxIcon when type is Inbox', () => {
    render(<ProjectIcon type={ProjectType.Inbox} />)
    const svg = screen.getByTestId('InboxIcon')
    expect(svg).toBeInTheDocument()
  })

  it('renders TagIcon by default', () => {
    render(<ProjectIcon type={ProjectType.Project} />)
    const svg = screen.getByTestId('TagIcon')
    expect(svg).toBeInTheDocument()
  })
})
