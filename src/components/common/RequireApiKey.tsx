import { LoadingView } from '@components/common'
import settingsService from '@services/SettingsService'
import React, { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'

export interface RequireApiKeyProps {
  /**
   * Content to render when an API key is present.
   * Typically a route "Page" component (e.g., <StatisticsPage />).
   */
  children: React.ReactNode
}

/**
 * RequireApiKey — route guard for views that need a stored API key.
 *
 * - On mount, asynchronously checks with the setting service for an API key.
 * - While loading, renders <LoadingView />.
 * - If no key is found, redirects to `/settings` (via <Navigate replace />).
 * - If a key exists, renders `children`.
 */
export function RequireApiKey({ children }: RequireApiKeyProps) {
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
    return <LoadingView />
  }

  if (!hasKey) {
    return <Navigate to="/settings" replace />
  }
  return children
}
