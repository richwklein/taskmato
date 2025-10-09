import LoadingBox from '@components/LoadingBox'
import settingsService from '@services/SettingsService'
import React, { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'

/**
 * A wrapper component to enforce API key presence.
 *
 * If the API key is not set in localStorage, it redirects to the SettingsView.
 */
export function RequireApiKey({ children }: { children: React.ReactNode }) {
  const [isLoading, setLoading] = useState(true)
  const [hasKey, setHasKey] = useState(false)

  useEffect(() => {
    const fetchApiKey = async () => {
      const key = await settingsService.getApiKey()
      setHasKey(!!key)
      setLoading(false)
    }
    fetchApiKey()
  }, [])

  if (isLoading) {
    return <LoadingBox />
  }

  if (!hasKey) {
    return <Navigate to="/settings" replace />
  }
  return children
}
