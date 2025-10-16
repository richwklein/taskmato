import { RequireApiKey } from '@components/common'
import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'

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

import settingsService from '@services/SettingsService'

describe('RequireApiKey', () => {
  const mockedSettingsService = vi.mocked(settingsService)

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('shows LoadingView while checking for API key', async () => {
    // Delay resolution to simulate async loading
    mockedSettingsService.get.mockImplementationOnce(
      () => new Promise((resolve) => setTimeout(() => resolve(null), 10))
    )

    render(
      <MemoryRouter>
        <RequireApiKey>
          <div>Protected Content</div>
        </RequireApiKey>
      </MemoryRouter>
    )

    // LoadingView renders immediately
    expect(screen.getByRole('progressbar')).toBeInTheDocument()
  })

  it('renders children if API key exists', async () => {
    mockedSettingsService.get.mockImplementation(async (key) => {
      if (key === 'todoist.api.key') return 'FAKE_API_KEY'
      return null
    })

    render(
      <MemoryRouter>
        <RequireApiKey>
          <div data-testid="child">Child Content</div>
        </RequireApiKey>
      </MemoryRouter>
    )

    await waitFor(() => expect(mockedSettingsService.get).toHaveBeenCalled())

    expect(screen.getByTestId('child')).toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  it('redirects to settings if no API key found', async () => {
    mockedSettingsService.get.mockResolvedValueOnce(null)

    render(
      <MemoryRouter>
        <RequireApiKey>
          <div>Protected Content</div>
        </RequireApiKey>
      </MemoryRouter>
    )

    await waitFor(() => expect(mockedSettingsService.get).toHaveBeenCalled())

    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })
})
