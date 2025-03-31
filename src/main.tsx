import '@styles/main.css'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import Taskmato from './Taskmato'

const root = createRoot(document.getElementById('root')!)
root.render(
  <StrictMode>
    <Taskmato />
  </StrictMode>
)
