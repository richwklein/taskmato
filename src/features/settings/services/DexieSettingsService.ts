import { db } from '@common/db'
import type { SettingsKey, SettingsTypeMap } from '@common/settings'
import { settings } from '@common/settings'

import { SettingsService } from './SettingsService'

export class DexieSettingsService implements SettingsService {
  private eventTarget = new EventTarget()

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
