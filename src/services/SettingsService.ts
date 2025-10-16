import { db } from '@utils/db'
import { settings } from '@utils/settings'

type SettingsKey = (typeof settings.type)['Key']
type SettingsTypeMap = (typeof settings.type)['TypeMap']

/* -------------------------------------------------------------------------- */
/*                             SETTINGS SERVICE API                           */
/* -------------------------------------------------------------------------- */

/**
 * Provides type-safe get/set access to application settings.
 * Uses IndexedDB (via `db.settings`) for persistence and supports
 * event-driven updates through {@link getWithListener}.
 */
export interface ISettingsService {
  /**
   * Get the value for a specific {@link SettingsKey}.
   * @param key The settings key to retrieve.
   * @returns The stored value or a reasonable default if not present.
   */
  get<K extends SettingsKey>(key: K): Promise<SettingsTypeMap[K]>

  /**
   * Set the value for a specific {@link SettingsKey}.
   * @param key The settings key to update.
   * @param value The new value to store.
   */
  set<K extends SettingsKey>(key: K, value: SettingsTypeMap[K]): Promise<void>

  /**
   * Get a setting and listen for future updates.
   * The listener will be called immediately with the current value,
   * then whenever the setting changes.
   * @param key The settings key to observe.
   * @param listener Callback invoked with the latest value.
   * @returns A function to unsubscribe from further updates.
   */
  getWithListener<K extends SettingsKey>(
    key: K,
    listener: (value: SettingsTypeMap[K]) => void
  ): Promise<() => void>
}

class SettingsService implements ISettingsService {
  private static instance: SettingsService
  private eventTarget = new EventTarget()

  private constructor() {}

  private async getSetting<K extends SettingsKey>(key: K): Promise<SettingsTypeMap[K] | null> {
    const record = await db.settings.get(key)
    return (record?.value ?? null) as SettingsTypeMap[K] | null
  }

  private async setSetting<K extends SettingsKey>(
    key: K,
    value: SettingsTypeMap[K]
  ): Promise<void> {
    await db.settings.put({ key, value })
    this.eventTarget.dispatchEvent(new CustomEvent(key, { detail: value }))
  }

  static getInstance() {
    if (!this.instance) {
      this.instance = new SettingsService()
    }
    return this.instance
  }

  async get<K extends SettingsKey>(key: K): Promise<SettingsTypeMap[K]> {
    const value = await this.getSetting(key)

    // TODO decrypt secure settings

    return value ?? settings.defaults[key]
  }

  async set<K extends SettingsKey>(key: K, value: SettingsTypeMap[K]): Promise<void> {
    const toStore: SettingsTypeMap[K] = value

    // TODO encrypt secure settings
    await this.setSetting(key, toStore)
  }

  async getWithListener<K extends SettingsKey>(
    key: K,
    listener: (value: SettingsTypeMap[K]) => void
  ): Promise<() => void> {
    const current = await this.get(key)
    listener(current)
    const handler = (event: Event) => listener((event as CustomEvent).detail)
    this.eventTarget.addEventListener(key, handler)
    return () => this.eventTarget.removeEventListener(key, handler)
  }
}

export default SettingsService.getInstance()
