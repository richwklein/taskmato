import '@common/main.css'

import theme from '@common/theme'
import { CssBaseline, ThemeProvider } from '@mui/material'
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
