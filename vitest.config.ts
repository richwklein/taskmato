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
    coverage: {
      include: ['**/src/**'],
      extension: ['.js', '.cjs', '.mjs', '.ts', '.tsx'],
      reporter: ['text', 'json-summary', 'json'],
      reportsDirectory: './coverage',
      reportOnFailure: true,
      /** TODO re-enable thresholds once we reach them
      thresholds: {
        lines: 60,
        branches: 60,
        functions: 60,
        statements: 60,
      }, */
    },
  },
})
