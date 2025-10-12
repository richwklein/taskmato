import { GlobalToolbar } from '@components/global/GlobalToolbar'
import { render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it } from 'vitest'

describe('GlobalToolbar', () => {
  const renderToolbar = (props = {}) =>
    render(
      <MemoryRouter>
        <GlobalToolbar {...props} />
      </MemoryRouter>
    )

  it('renders the app title', () => {
    renderToolbar()
    expect(screen.getByRole('heading', { name: /taskmato/i })).toBeInTheDocument()
  })

  it('wraps the icon and app title in a link to the home page', () => {
    renderToolbar()

    const homeLink = screen.getByRole('link', { name: /go to home/i })
    expect(homeLink).toBeInTheDocument()
    expect(homeLink).toHaveAttribute('href', '/')

    expect(within(homeLink).getByText('Taskmato')).toBeInTheDocument()
    expect(homeLink.querySelector('svg')).not.toBeNull()
  })

  it('renders navigation buttons for Home, Statistics, and Settings', () => {
    renderToolbar()

    const nav = screen.getByRole('navigation', { name: /global navigation/i })
    const homeButton = within(nav).getByRole('link', { name: /home/i })
    const statsButton = within(nav).getByRole('link', { name: /statistics/i })
    const settingsButton = within(nav).getByRole('link', { name: /settings/i })

    expect(homeButton).toBeInTheDocument()
    expect(statsButton).toBeInTheDocument()
    expect(settingsButton).toBeInTheDocument()
  })

  it('links to the correct routes', () => {
    renderToolbar()

    const nav = screen.getByRole('navigation', { name: /global navigation/i })
    const homeButton = within(nav).getByRole('link', { name: /home/i })
    const statsButton = within(nav).getByRole('link', { name: /statistics/i })
    const settingsButton = within(nav).getByRole('link', { name: /settings/i })

    expect(homeButton.closest('a')).toHaveAttribute('href', '/')
    expect(statsButton.closest('a')).toHaveAttribute('href', '/statistics')
    expect(settingsButton.closest('a')).toHaveAttribute('href', '/settings')
  })
})
