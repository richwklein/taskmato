import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'astro/config'

// https://astro.build/config
export default defineConfig({
  site: 'https://richwklein.github.io',
  base: '/taskmato',
  output: 'static',
  vite: { plugins: [tailwindcss()] },
})
