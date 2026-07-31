# Marketing Site

The Taskmato marketing site is an Astro 6 static site hosted on GitHub Pages. It lives in the `site/` directory at the repo root.

## Local development

Node.js 22.22.3 and pnpm 10.24.0 are pinned in the repo's `.tool-versions`. Install them via `asdf install`, then:

```bash
cd site
pnpm install
pnpm run dev
```

The dev server starts at `http://localhost:3000`.

## Building for production

```bash
cd site
pnpm run build
```

Static HTML is written to `site/dist/`. Assets are prefixed with the GitHub Pages base path `/taskmato/`, so paths like `/css/style.css` become `/taskmato/css/style.css` in the final HTML.

## Available commands

All commands below assume you're in the `site/` directory:

- `pnpm run dev` — Start the Astro dev server
- `pnpm run preview` — Preview the production build locally
- `pnpm run build` — Build for production (runs `astro check` + static build)
- `pnpm run lint` — Check for ESLint violations
- `pnpm run lint:fix` — Fix ESLint violations
- `pnpm run format` — Check code formatting with Prettier
- `pnpm run format:fix` — Format code in-place
- `pnpm run test` — Run Vitest unit tests
- `pnpm run test:coverage` — Run tests with coverage report
- `pnpm run verify` — Run lint, format, test, and build (the CI check)
- `pnpm run clean` — Remove `.astro/`, `dist/`, `node_modules/`, `coverage/`

Or use the Makefile shortcuts from the repo root:

- `make site-dev` — Alias for `cd site && pnpm install && pnpm run dev`
- `make site-build` — Alias for `cd site && pnpm install && pnpm run build`
- `make site-install` — Just install dependencies

## GitHub Pages deployment

Deployment automation lives in [#289](https://github.com/richwklein/taskmato/issues/289). Once merged, the CI workflow will build `site/` and deploy `site/dist/` to the `gh-pages` branch, which GitHub Pages serves at `https://richwklein.github.io/taskmato/`.

## Custom domain

The site currently targets the default GitHub Pages URL with `base: '/taskmato'` in `astro.config.ts`. Moving to a custom domain (`taskmato.com`) requires:

1. A CNAME file in the repository root pointing to `richwklein.github.io`
2. Updating `astro.config.ts` to use `base: '/'`
3. DNS configuration via your registrar (e.g., Bluehost)

This is tracked in [#288](https://github.com/richwklein/taskmato/issues/288) (milestone 1.3.0).

## Content & design

Landing page content is tracked in [#365](https://github.com/richwklein/taskmato/issues/365). The page layout uses Tailwind CSS 4 for styling.
