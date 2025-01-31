import { ProjectIcon } from '@features/projects/project-icon'
import { render, screen } from '@testing-library/react'
import { ProjectType } from '@types'
import { describe, expect, it } from 'vitest'

describe('ProjectIcon', () => {
  it.todo('Do not rely on the internal test ids')

  it('renders the Today icon when type is Today', () => {
    render(<ProjectIcon type={ProjectType.Today} />)
    expect(screen.getByTestId('TodayIcon')).toBeInTheDocument()
  })

  it('renders the Inbox icon when type is Inbox', () => {
    render(<ProjectIcon type={ProjectType.Inbox} />)
    expect(screen.getByTestId('InboxIcon')).toBeInTheDocument()
  })

  it('renders the default Tag icon when type is Project', () => {
    render(<ProjectIcon type={ProjectType.Project} />)
    expect(screen.getByTestId('TagIcon')).toBeInTheDocument()
  })
})
