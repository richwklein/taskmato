import { ThemeSetting } from '@components/settings/ThemeSetting'
import settingsService from '@services/SettingsService' // <- uses the global mock
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const mockedSettings = vi.mocked(settingsService)

describe('ThemeSetting', () => {
  const user = userEvent.setup()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders all theme options', () => {
    render(<ThemeSetting />)

    expect(screen.getByLabelText(/light/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/dark/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/system/i)).toBeInTheDocument()
  })

  it('loads and displays the saved theme mode on mount', async () => {
    // Override default mock to return dark mode
    mockedSettings.getThemeMode.mockResolvedValueOnce('dark')

    render(<ThemeSetting />)

    // wait for async effect to finish
    await waitFor(() => {
      expect(settingsService.getThemeMode).toHaveBeenCalled()
    })

    const darkRadio = screen.getByLabelText(/dark/i)
    await waitFor(() => expect(darkRadio).toBeChecked())
  })

  it('calls setThemeMode and updates selection when user changes theme', async () => {
    mockedSettings.getThemeMode.mockResolvedValueOnce('light')
    mockedSettings.setThemeMode.mockResolvedValueOnce(undefined)

    render(<ThemeSetting />)
    const darkRadio = await screen.findByLabelText(/dark/i)
    await user.click(darkRadio)

    expect(darkRadio).toBeChecked()

    await waitFor(() => {
      expect(settingsService.setThemeMode).toHaveBeenCalledExactlyOnceWith('dark')
    })
  })
})
