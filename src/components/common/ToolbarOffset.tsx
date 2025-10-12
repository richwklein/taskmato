import { styled } from '@mui/material'

/**
 * ToolbarOffset — a spacer div equal to the theme’s toolbar height.
 *
 * Uses `theme.mixins.toolbar` to create a block with the same height as
 * the Material UI `<Toolbar />`. Commonly placed at the top of drawers
 * and main content when the `AppBar` is `position="fixed"` to prevent
 * content from appearing under the app bar.
 *
 * Notes:
 * - Respects responsive toolbar heights defined by the theme (e.g., dense).
 * - Safe to use multiple times (pure spacer, no visual chrome).
 */
export const ToolbarOffset = styled('div')(({ theme }) => theme.mixins.toolbar)

export default ToolbarOffset
