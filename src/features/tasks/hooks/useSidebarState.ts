import theme from '@common/theme'
import { useSettingsService } from '@features/settings/hooks/useSettingsService'
import { useMediaQuery } from '@mui/material'
import { useEffect, useRef, useState } from 'react'

export interface SidebarState {
  /** True when rendering a persistent sidebar; affects label text. */
  readonly isPersistent: boolean

  /** Current open/closed state of the Projects sidebar. */
  readonly isOpen: boolean

  /** Handler to toggle the sidebar open/closed. */
  toggleSidebar: () => Promise<void>
}

/**
 * useSidebarState — minimal sidebar API for consumers.
 *
 * Exposes only what callers need:
 *   - `isDesktop`: current layout breakpoint (md+)
 *   - `isOpen`:    sidebar visibility
 *   - `toggleSidebar()`: toggles and persists on desktop
 */
export function useSidebarState() {
  const settings = useSettingsService()
  const isDesktop = useMediaQuery(theme.breakpoints.up('md'))
  const [isOpen, setIsOpen] = useState(true)
  const [isClosing, setIsClosing] = useState(false)
  const prevIsDesktopRef = useRef(isDesktop)

  const handleClosing = () => {
    setIsClosing(true)
    setIsOpen(false)
  }

  const handleClosed = () => {
    setIsClosing(false)
  }

  const toggleSidebar = async () => {
    if (isClosing) return
    const newState = !isOpen
    setIsOpen(newState)
    if (isDesktop) await settings.set('ui.sidebar.open', newState)
  }

  useEffect(() => {
    let canceled = false
    const fetchOpen = async () => {
      const open = await settings.get('ui.sidebar.open')
      if (!canceled) setIsOpen(open)
    }

    if (!prevIsDesktopRef.current && isDesktop) {
      fetchOpen()
    }
    prevIsDesktopRef.current = isDesktop
    return () => {
      canceled = true
    }
  }, [isDesktop])

  return { isDesktop, isOpen, isClosing, toggleSidebar, handleClosing, handleClosed }
}
