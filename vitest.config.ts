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
      /** TODO increase coverage as we add tests */
      thresholds: {
        statements: 35,
        branches: 75,
        functions: 55,
        lines: 35,
      },
    },
  },
})
