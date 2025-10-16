import { ThemeSetting } from '@components/settings/ThemeSetting'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'

// locally mock for this suite
vi.mock('@services/SettingsService', () => {
  return {
    default: {
      get: vi.fn(),
      set: vi.fn(),
      getWithListener: vi.fn(),
    },
  }
})

// Import after the mock
import settingsService from '@services/SettingsService'

describe('ThemeSetting', () => {
  const user = userEvent.setup()
  const mockedSettingsService = vi.mocked(settingsService)

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders all theme options', () => {
    render(<ThemeSetting />)

    expect(screen.getByLabelText(/light/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/dark/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/system/i)).toBeInTheDocument()
  })

  it('loads and displays saved theme', async () => {
    mockedSettingsService.get.mockImplementation(async (key) => {
      if (key === 'ui.theme.mode') return 'dark'
      return null
    })

    render(<ThemeSetting />)
    await waitFor(() =>
      expect(mockedSettingsService.get).toHaveBeenCalledExactlyOnceWith('ui.theme.mode')
    )
    expect(screen.getByLabelText(/dark/i)).toBeChecked()
  })

  it('calls set when theme changes', async () => {
    mockedSettingsService.get.mockImplementation(async (key) => {
      if (key === 'ui.theme.mode') return 'light'
      return null
    })

    render(<ThemeSetting />)
    const darkRadio = await screen.findByLabelText(/dark/i)
    await user.click(darkRadio)

    expect(mockedSettingsService.set).toHaveBeenCalledExactlyOnceWith('ui.theme.mode', 'dark')
  })
})
