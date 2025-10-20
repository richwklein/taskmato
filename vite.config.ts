import react from '@vitejs/plugin-react'
import path from 'path'
import { defineConfig } from 'vite'

export const alias = {
  '@app': path.resolve(__dirname, 'src/app'),
  '@common': path.resolve(__dirname, 'src/common'),
  '@features': path.resolve(__dirname, 'src/features'),
  '@components': path.resolve(__dirname, 'src/components'),
  '@types': path.resolve(__dirname, 'src/types'),
  '@utils': path.resolve(__dirname, 'src/utils'),
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias,
  },
})
