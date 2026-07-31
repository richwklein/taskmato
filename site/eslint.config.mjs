import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { includeIgnoreFile } from '@eslint/compat'
import jsLint from '@eslint/js'
import vitestLint from '@vitest/eslint-plugin'
import astroLint from 'eslint-plugin-astro'
import sortLint from 'eslint-plugin-simple-import-sort'
import tsLint from 'typescript-eslint'

const filename = fileURLToPath(import.meta.url)
const dirname = path.dirname(filename)
const gitignorePath = path.resolve(dirname, '.gitignore')

export default [
  includeIgnoreFile(gitignorePath),
  jsLint.configs.recommended,
  ...tsLint.configs.recommended,
  ...astroLint.configs.recommended,
  ...astroLint.configs['jsx-a11y-recommended'],
  {
    plugins: {
      'simple-import-sort': sortLint,
      vitest: vitestLint,
    },
    rules: {
      'astro/prefer-class-list-directive': 'error',
      'simple-import-sort/imports': 'error',
      'simple-import-sort/exports': 'error',
      '@typescript-eslint/no-explicit-any': 'off',
      ...vitestLint.configs.recommended.rules,
      'vitest/prefer-lowercase-title': 'error',
    },
  },
]
