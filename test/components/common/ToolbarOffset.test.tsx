import { ToolbarOffset } from '@components/common'
import { createTheme, ThemeProvider } from '@mui/material/styles'
import { render, screen } from '@testing-library/react'
import React from 'react'
import { describe, expect, it } from 'vitest'

/** Helper to render with a theme */
function renderWithTheme(ui: React.ReactElement, theme = createTheme()) {
  return render(<ThemeProvider theme={theme}>{ui}</ThemeProvider>)
}

describe('ToolbarOffset', () => {
  it('renders a div and forwards props (e.g., data-testid)', () => {
    renderWithTheme(<ToolbarOffset data-testid="offset" />)
    const el = screen.getByTestId('offset')
    expect(el.tagName.toLowerCase()).toBe('div')
  })

  it('applies min-height equal to theme.mixins.toolbar.minHeight (default theme)', () => {
    const theme = createTheme()
    renderWithTheme(<ToolbarOffset data-testid="offset" />, theme)

    const el = screen.getByTestId('offset')
    const style = window.getComputedStyle(el)

    const expected = `${theme.mixins.toolbar.minHeight}px`
    expect(style.minHeight).toBe(expected)
  })

  it('respects custom theme mixins.toolbar override', () => {
    const custom = createTheme({
      mixins: {
        toolbar: { minHeight: 80 },
      },
    })

    renderWithTheme(<ToolbarOffset data-testid="offset" />, custom)

    const el = screen.getByTestId('offset')
    const style = window.getComputedStyle(el)
    expect(style.minHeight).toBe('80px')
  })
})
