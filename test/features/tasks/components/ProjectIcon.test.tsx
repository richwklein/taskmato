import { ProjectIcon } from '@features/tasks/components/ProjectIcon'
import { render, screen } from '@testing-library/react'
import { PROJECT_TYPE } from '@types'
import { describe, expect, it } from 'vitest'

describe('ProjectIcon', () => {
  it.todo('Stop using internal test ids')

  it('renders TodayIcon when type is Today', () => {
    render(<ProjectIcon type={PROJECT_TYPE.Today} />)
    const svg = screen.getByTestId('TodayIcon')
    expect(svg).toBeInTheDocument()
  })

  it('renders InboxIcon when type is Inbox', () => {
    render(<ProjectIcon type={PROJECT_TYPE.Inbox} />)
    const svg = screen.getByTestId('InboxIcon')
    expect(svg).toBeInTheDocument()
  })

  it('renders TagIcon by default', () => {
    render(<ProjectIcon type={PROJECT_TYPE.Project} />)
    const svg = screen.getByTestId('TagIcon')
    expect(svg).toBeInTheDocument()
  })
})
