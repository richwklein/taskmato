import '@styles/main.css'

import { CssBaseline, ThemeProvider } from '@mui/material'
import theme from '@styles/theme'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'

import Taskmato from './Taskmato'

const root = createRoot(document.getElementById('root')!)
root.render(
  <StrictMode>
    <ThemeProvider theme={theme} noSsr>
      <CssBaseline />
      <BrowserRouter>
        <Taskmato />
      </BrowserRouter>
    </ThemeProvider>
  </StrictMode>
)
