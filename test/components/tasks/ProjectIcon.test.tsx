import { ProjectIcon } from '@components/tasks'
import { render, screen } from '@testing-library/react'
import { ProjectType } from '@types'
import { describe, expect, it } from 'vitest'

describe('ProjectIcon', () => {
  it('renders TodayIcon when type is Today', () => {
    render(<ProjectIcon type={ProjectType.Today} title={'Today'} />)
    const svg = screen.getByRole('img', { name: /today/i })
    expect(svg).toBeInTheDocument()
  })

  it('renders InboxIcon when type is Inbox', () => {
    render(<ProjectIcon type={ProjectType.Inbox} title={'Inbox'} />)
    const svg = screen.getByRole('img', { name: /inbox/i })
    expect(svg).toBeInTheDocument()
  })

  it('renders TagIcon by default', () => {
    render(<ProjectIcon type={ProjectType.Project} title={'Family'} />)
    const svg = screen.getByRole('img', { name: /family/i })
    expect(svg).toBeInTheDocument()
  })
})
