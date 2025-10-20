import { createTheme } from '@mui/material/styles'

/**
 * The base Material UI theme configuration for **Taskmato**.
 *
 * This theme enables MUI's dark color scheme and provides the foundation
 * for global component styling, spacing, and typography across the app.
 *
 * @see {@link ThemeModeApplier} for dynamic theme switching.
 */
export default createTheme({
  colorSchemes: {
    dark: true,
  },
})
