import { SettingsType } from '@types'

/** Describes an individual setting and its default value. */
export interface SettingDefinition {
  /** The key used for getting/saving the setting. */
  key: string

  /** The default value for the setting if none is stored. */
  default: SettingsType

  /** A human-readable description of the setting. */
  description: string

  /** The settings should be stored in a "secure" manner. */
  isSecure?: boolean
}

/**
 * Creates a strongly typed settings schema from a list of descriptors.
 *
 * Each descriptor defines a key, default value, and description.
 * The returned object includes both the full list of descriptors (`defs`)
 * and a `defaults` map suitable for initializing the {@link SettingsService}.
 */
export function createSettings<const T extends readonly SettingDefinition[]>(defs: T) {
  return {
    defs,
    defaults: Object.fromEntries(defs.map((d) => [d.key, d.default])) as {
      [K in T[number]['key']]: Extract<T[number], { key: K }>['default']
    },
  }
}
