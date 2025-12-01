import { ThemeSetting } from '@features/settings/components/ThemeSetting'
import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

describe('<ThemeSetting />', () => {
  it('renders the appearance label and all theme options', () => {
    render(<ThemeSetting value="system" onChange={vi.fn()} />)

    // Group label
    expect(screen.getByText('Appearance')).toBeInTheDocument()

    // Options
    expect(screen.getByLabelText('Light')).toBeInTheDocument()
    expect(screen.getByLabelText('Dark')).toBeInTheDocument()
    expect(screen.getByLabelText('System')).toBeInTheDocument()
  })

  it('selects the correct radio button for the current value', () => {
    render(<ThemeSetting value="dark" onChange={vi.fn()} />)
    const darkOption = screen.getByLabelText('Dark') as HTMLInputElement
    expect(darkOption.checked).toBe(true)
  })

  it('calls onChange with the new value when selection changes', () => {
    const handleChange = vi.fn()
    render(<ThemeSetting value="light" onChange={handleChange} />)

    const darkOption = screen.getByLabelText('Dark')
    fireEvent.click(darkOption)

    expect(handleChange).toHaveBeenCalledTimes(1)
    expect(handleChange).toHaveBeenCalledExactlyOnceWith('dark')
  })

  it('applies custom sx styles', () => {
    render(<ThemeSetting value="light" onChange={vi.fn()} sx={{ bgcolor: 'red' }} />)

    const fieldset = screen.getByRole('radiogroup').closest('fieldset') as HTMLElement
    const style = window.getComputedStyle(fieldset)

    expect(style.backgroundColor).toBe('rgb(255, 0, 0)')
  })
})
