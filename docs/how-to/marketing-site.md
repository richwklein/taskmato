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

Static HTML is written to `site/dist/`. The site is served from the root of a custom domain, so `astro.config.ts` sets no `base` and asset paths are emitted unprefixed (`/icon.png`, not `/taskmato/icon.png`).

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

The site is published to GitHub Pages by [`.github/workflows/site-deploy.yaml`](../../.github/workflows/site-deploy.yaml) using the artifact-upload flow — there is no `gh-pages` branch. The workflow builds `site/` and uploads `site/dist/` as the Pages artifact.

It runs in two situations:

- **On release** — `code-release.yaml` calls it after a release is published, so the live site always matches a tagged version.
- **Manually** — `workflow_dispatch` for an out-of-band redeploy, optionally against a specific `ref`.

Merging a change under `site/` does **not** deploy it. A release or a manual dispatch is required.

## Custom domain

The site is served at `https://taskmato.com`. The pieces that make that work:

| Layer          | Setting                                                                                              |
| -------------- | ---------------------------------------------------------------------------------------------------- |
| Registrar      | Bluehost (also hosts the DNS zone)                                                                   |
| Apex `A`       | `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`                            |
| `www` `CNAME`  | `richwklein.github.io`                                                                               |
| Verification   | `_github-pages-challenge-richwklein` `TXT`, from github.com/settings/pages                             |
| Repo setting   | Custom domain `taskmato.com` with **Enforce HTTPS** enabled                                          |
| Astro          | `site: 'https://taskmato.com'`, no `base`                                                            |

Because Pages publishes from a workflow rather than a branch, the custom domain lives in the repository's Pages settings; a `CNAME` file in the build artifact is not required.

Domain verification is what stops another GitHub account from claiming `taskmato.com` if it is ever unassigned here — keep the TXT record in place.

GitHub redirects the default `richwklein.github.io/taskmato` URL to the custom domain automatically, so older links keep working.

## Content & design

Landing page content is tracked in [#365](https://github.com/richwklein/taskmato/issues/365). The page layout uses Tailwind CSS 4 for styling.
