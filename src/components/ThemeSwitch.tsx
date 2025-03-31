import { Brightness4, Brightness7 } from '@mui/icons-material'
import { styled, Switch, SwitchProps, useColorScheme, useMediaQuery } from '@mui/material'
import React from 'react'

/**
 * TODO this will be replace with something on the settings page
 */
const StyledThemeSwitch = styled(Switch)(({ theme }) => ({
  width: 62,
  height: 34,
  padding: 7,
  '& .MuiSwitch-switchBase': {
    margin: 1,
    padding: 0,
    transform: 'translateX(6px)',
    '&.Mui-checked': {
      color: '#fff',
      transform: 'translateX(22px)',
      '& .MuiSwitch-thumb:before': {
        content: '" "',
        position: 'absolute',
        width: '100%',
        height: '100%',
        left: 0,
        top: 0,
        backgroundRepeat: 'no-repeat',
        backgroundPosition: 'center',
        backgroundImage: `url(${Brightness7})`,
      },
      '& + .MuiSwitch-track': {
        opacity: 1,
        backgroundColor: theme.palette.mode === 'dark' ? '#8796A5' : '#aab4be',
      },
    },
  },
  '& .MuiSwitch-thumb': {
    backgroundColor: theme.palette.mode === 'dark' ? '#003892' : '#001e3c',
    width: 32,
    height: 32,
    '&:before': {
      content: '" "',
      position: 'absolute',
      width: '100%',
      height: '100%',
      left: 0,
      top: 0,
      backgroundRepeat: 'no-repeat',
      backgroundPosition: 'center',
      backgroundImage: `url(${Brightness4})`,
    },
  },
  '& .MuiSwitch-track': {
    opacity: 1,
    backgroundColor: theme.palette.mode === 'dark' ? '#8796A5' : '#aab4be',
    borderRadius: 20 / 2,
  },
}))

const ThemeSwitch: React.FC<SwitchProps> = (props) => {
  const prefersDarkMode = useMediaQuery('(prefers-color-scheme: dark)')
  const { mode, setMode } = useColorScheme()
  if (!mode) {
    setMode(prefersDarkMode ? 'dark' : 'light')
  }

  const handleThemeChange = () => {
    setMode(mode === 'dark' ? 'light' : 'dark')
  }

  return <StyledThemeSwitch onChange={handleThemeChange} {...props} />
}

export default ThemeSwitch
