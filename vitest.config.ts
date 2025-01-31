import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

import { alias } from './vite.config'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    alias: alias,
    setupFiles: '/test/setup.ts',
  },
})
