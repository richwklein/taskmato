import jsLint from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

import importSort from "eslint-plugin-simple-import-sort";
import tsLint from "typescript-eslint";

export default tsLint.config({
  extends: [jsLint.configs.recommended, ...tsLint.configs.recommended],
  files: ["**/*.{ts,tsx}"],
  languageOptions: {
    ecmaVersion: 2022,
  },
  plugins: {
    "simple-import-sort": importSort,
    "react-hooks": reactHooks,
    "react-refresh": reactRefresh,
  },
  rules: {
    ...reactHooks.configs.recommended.rules,
    "react-refresh/only-export-components": [
      "warn",
      { allowConstantExport: true },
    ],
    "simple-import-sort/imports": "error",
    "simple-import-sort/exports": "error",
  },
});
