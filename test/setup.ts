import '@testing-library/jest-dom'

import { vi } from 'vitest'

// Global mock for the settings service
vi.mock('@services/SettingsService', () => ({
  default: {
    getThemeMode: vi.fn().mockResolvedValue('system'),
    getThemeModeWithListner: vi
      .fn()
      .mockImplementation(async (listener: (mode: string) => void) => {
        listener('system')
        return () => {}
      }),
    setThemeMode: vi.fn(),
    getApiKey: vi.fn().mockResolvedValue(null),
    setApiKey: vi.fn(),
  },
}))
