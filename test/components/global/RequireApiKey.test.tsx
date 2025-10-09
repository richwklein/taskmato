import { RequireApiKey } from '@components/global/RequireApiKey'
import settingsService from '@services/SettingsService'
import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'

// Use the globally mocked SettingsService but override behavior per test
const mockedSettingsService = vi.mocked(settingsService)

describe('RequireApiKey', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('shows LoadingBox while checking for API key', async () => {
    // Delay resolution to simulate async loading
    mockedSettingsService.getApiKey.mockImplementationOnce(
      () => new Promise((resolve) => setTimeout(() => resolve(null), 10))
    )

    render(
      <MemoryRouter>
        <RequireApiKey>
          <div>Protected Content</div>
        </RequireApiKey>
      </MemoryRouter>
    )

    // LoadingBox renders immediately
    expect(screen.getByRole('progressbar')).toBeInTheDocument()
  })

  it('renders children if API key exists', async () => {
    mockedSettingsService.getApiKey.mockResolvedValueOnce('FAKE_API_KEY')

    render(
      <MemoryRouter>
        <RequireApiKey>
          <div data-testid="child">Child Content</div>
        </RequireApiKey>
      </MemoryRouter>
    )

    await waitFor(() => expect(mockedSettingsService.getApiKey).toHaveBeenCalled())

    expect(screen.getByTestId('child')).toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })

  it('redirects to settings if no API key found', async () => {
    mockedSettingsService.getApiKey.mockResolvedValueOnce(null)

    render(
      <MemoryRouter>
        <RequireApiKey>
          <div>Protected Content</div>
        </RequireApiKey>
      </MemoryRouter>
    )

    await waitFor(() => expect(mockedSettingsService.getApiKey).toHaveBeenCalled())

    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
  })
})
