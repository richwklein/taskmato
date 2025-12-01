import { SessionContext } from '@features/session/context/SessionContext'
import { useContext } from 'react'

/**
 * useSessionContext - hook to access the {@link SessionContext}.
 */
export function useSessionContext() {
  const ctx = useContext(SessionContext)
  if (!ctx) throw new Error('useSessionContext must be used within a SessionProvider')
  return ctx
}
