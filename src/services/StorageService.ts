/* eslint-disable @typescript-eslint/no-explicit-any */

export interface IStorageService {
  setItem(key: string, value: Record<string, any>): void
  getItem(key: string): Record<string, any> | null
  removeItem(key: string): void
  clear(): void
}

/**
 * StorageService
 *
 * The storage service is a singleton used to put and retrieve json encoded
 * information from storage. The base implementation uses localStorage.
 */
export class StorageService implements IStorageService {
  private static instance: StorageService
  private storage: Storage

  constructor(storage: Storage = localStorage) {
    this.storage = storage
  }

  /**
   * Gets the singleton instance of the StorageService.
   * @returns The singleton instance of the StorageService.
   */
  public static getInstance(): StorageService {
    if (!StorageService.instance) {
      StorageService.instance = new StorageService()
    }
    return StorageService.instance
  }

  /**
   * Sets an item in the storage.
   * @param key - The key under which the value is stored.
   * @param value - The value to store, as a record.
   */
  setItem(key: string, value: Record<string, any>): void {
    const serializedValue = JSON.stringify(value)
    this.storage.setItem(key, serializedValue)
  }

  /**
   * Retrieves an item from the storage.
   *
   * If there is no item or serialization fails then null is returned.
   *
   * @param key - The key of the item to retrieve.
   * @returns The retrieved item as a record, or null if not found.
   */
  getItem(key: string): Record<string, any> | null {
    const serializedValue = this.storage.getItem(key)
    if (serializedValue) {
      try {
        return JSON.parse(serializedValue) as Record<string, any>
      } catch (error) {
        console.error('Failed to parse stored value', error)
        return null
      }
    }
    return null
  }

  /**
   * Removes an item from the storage.
   * @param key - The key of the item to remove.
   */
  removeItem(key: string): void {
    this.storage.removeItem(key)
  }

  /**
   * Clears all items from the storage.
   */
  clear(): void {
    this.storage.clear()
  }
}

export default StorageService.getInstance()
