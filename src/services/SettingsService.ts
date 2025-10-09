import { db } from '@utils/db'

export type SettingValue = string | number | boolean
export type ThemeMode = 'light' | 'dark' | 'system'

/**
 * A service that is responsible for getting and saving settings.
 */
export interface ISettingsService {
  /**
   * Get the current {@link ThemeMode | theme mode}, default to 'system if not set.
   */
  getThemeMode(): Promise<ThemeMode>

  /**
   * Get the current {@link ThemeMode | theme mode} and listen for changes.
   * The listener will be called immediately with the current setting.
   *
   * @param listener A callback function that receives the updated theme mode.
   * @returns A function to unsubscribe from further updates.
   */
  getThemeModeWithListener(listener: (mode: ThemeMode) => void): Promise<() => void>

  /**
   * Set the {@link ThemeMode | theme mode} setting.
   * @param mode The theme mode to set: 'light', 'dark', or 'system'.
   */
  setThemeMode(mode: ThemeMode): Promise<void>

  /**
   * Get the stored Todoist API key.
   * @returns The stored Todoist API key, or null if not set.
   */
  getApiKey(): Promise<string | null>

  /**
   * Set the Todoist API key.
   * @param key The Todoist API key to store.
   */
  setApiKey(key: string): Promise<void>
}

class SettingsService implements ISettingsService {
  private static instance: SettingsService
  private eventTarget = new EventTarget()

  private constructor() {}

  private async getSetting(key: string): Promise<SettingValue | null> {
    const setting = await db.settings.get(key)
    return setting ? setting.value : null
  }

  private async setSetting(key: string, value: SettingValue): Promise<void> {
    await db.settings.put({ key, value })
    this.notify(key, value)
  }

  private notify(key: string, value: SettingValue) {
    this.eventTarget.dispatchEvent(new CustomEvent(key, { detail: value }))
  }

  private addListener(key: string, listener: (value: SettingValue) => void) {
    const handler = ((event: CustomEvent<SettingValue>) => {
      listener(event.detail)
    }) as EventListener
    this.eventTarget.addEventListener(key, handler)
    return () => this.eventTarget.removeEventListener(key, handler)
  }

  static getInstance() {
    if (!this.instance) {
      this.instance = new SettingsService()
    }
    return this.instance
  }

  async getThemeMode(): Promise<ThemeMode> {
    const mode = await this.getSetting('theme.mode')
    return (mode as ThemeMode) || 'system'
  }

  async getThemeModeWithListener(listener: (mode: ThemeMode) => void): Promise<() => void> {
    const currentMode = await this.getThemeMode()
    listener(currentMode)
    return this.addListener('theme.mode', (value) => {
      listener(value as ThemeMode)
    })
  }

  async setThemeMode(mode: ThemeMode): Promise<void> {
    await this.setSetting('theme.mode', mode)
  }

  async getApiKey(): Promise<string | null> {
    // TODO decrypte the key if encrypted
    const key = await this.getSetting('todoist.api.key')
    return key as string | null
  }

  async setApiKey(key: string): Promise<void> {
    // TODO encrypt the key before storing
    await this.setSetting('todoist.api.key', key)
  }
}

export default SettingsService.getInstance()
