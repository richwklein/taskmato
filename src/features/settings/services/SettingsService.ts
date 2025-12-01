import type { SettingsKey, SettingsTypeMap } from '@common/settings'

/**
 * Provides type-safe get/set access to application settings.
 * Uses IndexedDB (via `db.settings`) for persistence and supports
 * event-driven updates through {@link getWithListener}.
 */
export interface SettingsService {
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

export default SettingsService
