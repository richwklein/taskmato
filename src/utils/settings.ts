/** Possible setting value types that can be stored in the database. */
export type SettingValue = string | number | boolean | null

/**
 * A single setting descriptor with optional encryption flag.
 */
export interface SettingDescriptor {
  /** The key used for getting / saving the setting. */
  key: string

  /** A default value returned if the setting is not saved. */
  default: SettingValue

  /** A description of what this setting is for. */
  description: string
}

/**  Supported theme display modes. */
export type ThemeMode = 'light' | 'dark' | 'system'

/** Settings that are supported by the service. */
export const settings = createSettings([
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
] as const)

/**
 * Generic factory for defining strongly typed settings schemas.
 *
 * - Infers types from your descriptor list
 * - Provides runtime defaults
 * - Collects secure keys for encryption/decryption
 */
function createSettings<const T extends readonly SettingDescriptor[]>(defs: T) {
  const defaults = Object.fromEntries(defs.map((s) => [s.key, s.default])) as {
    [K in T[number]['key']]: Extract<T[number], { key: K }>['default']
  }

  return {
    defaults,
    keys: defs.map((s) => s.key) as T[number]['key'][],
    type: null as unknown as {
      Key: T[number]['key']
      TypeMap: { [K in T[number]['key']]: Extract<T[number], { key: K }>['default'] }
    },
  }
}
