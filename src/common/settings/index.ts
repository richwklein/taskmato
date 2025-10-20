import { createSettings } from './createSettings'

/** The possible theme modes for the application UI. */
export type ThemeMode = 'light' | 'dark' | 'system'

/**
 * The type-safe schema of all registered application settings.
 *
 * Provides runtime defaults and compile-time key/type inference for use
 * throughout the application.
 */
export const settings = createSettings([
  {
    key: 'ui.theme.mode',
    description: 'The appearance for the application.',
    default: 'system' as ThemeMode,
  },
  {
    key: 'ui.sidebar.open',
    description: 'The open state of the project sidebar in desktop mode.',
    default: true as boolean,
  },
  {
    key: 'todoist.api.key',
    description: 'API key used to authorize requests to Todoist.',
    default: null as string | null,
  },
  {
    key: 'todoist.sync.token',
    description: 'Token used in API requests to indicate the current state to sync from.',
    default: null as string | null,
  },
])

/** Type alias for all supported setting keys. */
export type SettingsKey = (typeof settings.defs)[number]['key']

/** Map type that associates each setting key with its value type. */
export type SettingsTypeMap = {
  [K in SettingsKey]: Extract<(typeof settings.defs)[number], { key: K }>['default']
}
