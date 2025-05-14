import jsLint from '@eslint/js'
import react from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'

import importSort from 'eslint-plugin-simple-import-sort'
import tsLint from 'typescript-eslint'
import vitestLint from '@vitest/eslint-plugin'

export default tsLint.config({
  extends: [jsLint.configs.recommended, ...tsLint.configs.recommended],
  files: ['**/*.{ts,tsx}'],
  languageOptions: {
    ecmaVersion: 2022,
  },
  plugins: {
    react: react,
    'react-hooks': reactHooks,
    'react-refresh': reactRefresh,
    'simple-import-sort': importSort,
    vitest: vitestLint,
  },
  rules: {
    ...react.configs.recommended.rules,
    ...reactHooks.configs.recommended.rules,
    'react/react-in-jsx-scope': 'off',
    'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
    'simple-import-sort/imports': 'error',
    'simple-import-sort/exports': 'error',
    ...vitestLint.configs.recommended.rules,
  },
  settings: {
    react: {
      version: 'detect',
    },
  },
})
