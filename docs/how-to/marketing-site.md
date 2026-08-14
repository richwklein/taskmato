# Marketing Site

The Taskmato marketing site is an Astro 7 static site hosted on GitHub Pages. It lives in the `site/` directory at the repo root.

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
- `make site-verify` — Alias for `cd site && pnpm install && pnpm run verify` (lint → format → test → build; the CI check)

## Tests

Tests live in `site/test/`, mirroring the `src/` tree (`test/pages/`, `test/utils/`). This matches the sibling Astro projects and keeps test files out of `src/pages/`, where Astro would otherwise treat every `.ts` file as a route and try to build it as a page.

Page tests render components through Astro's Container API and import the page under test by relative path (`../../src/pages/privacy.astro`); shared helpers use the `@utils/*` alias. Coverage is scoped to `src/**`, so the test tree is excluded automatically and no Vitest configuration is needed to pick it up.

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
| Artifact       | [`site/public/CNAME`](../../site/public/CNAME) — copied verbatim to `dist/` and shipped in the Pages artifact |

Because Pages publishes from a workflow rather than a branch, the custom domain is stored in the repository's Pages settings and a `CNAME` file is not strictly required. One is committed anyway so the domain is versioned with the site and reasserted on every deploy — if the Pages setting is ever cleared (disabling and re-enabling Pages will do it), the next deploy restores the domain instead of silently serving from `richwklein.github.io`.

The tradeoff is two sources of truth. **To change the domain, update `site/public/CNAME` and the repository Pages setting together** — a stale file will overwrite the setting on the next deploy. Keep it in sync with `site: 'https://taskmato.com'` in `astro.config.ts` and `SITE_URL` in `src/utils/site.ts`, which feed canonical and Open Graph URLs.

Domain verification is what stops another GitHub account from claiming `taskmato.com` if it is ever unassigned here — keep the TXT record in place.

GitHub redirects the default `richwklein.github.io/taskmato` URL to the custom domain automatically, so older links keep working.

## Pages

| Route       | Purpose                                                                 |
| ----------- | ------------------------------------------------------------------------ |
| `/`         | Landing page                                                             |
| `/privacy`  | Privacy policy — the URL App Store Connect points at                    |
| `/support`  | Support contact, common questions, downloads                             |
| `/404`      | Not-found page; Astro emits `dist/404.html`, which GitHub Pages serves automatically for unknown paths on a custom domain — no extra config needed |

Merging a change to any of these does **not** publish it — see [GitHub Pages deployment](#github-pages-deployment) above; a release or manual dispatch is required.

## Content & design

Landing page content is tracked in [#365](https://github.com/richwklein/taskmato/issues/365) and the launch redesign in [#287](https://github.com/richwklein/taskmato/issues/287). The page layout uses Tailwind CSS 4 for styling.

### Design tokens

Every color, radius, and font used on the site is a Tailwind `@theme` custom property defined in [`site/src/styles/global.css`](../../site/src/styles/global.css) — nothing hardcodes a stock Tailwind gray or red. Reach for the token utility (`bg-canvas`, `text-ink`, `text-ink-muted`, `border-line`, `rounded-card`, `rounded-shell`, `font-sans`, `bg-provider-local`, `bg-provider-reminders`, `bg-provider-obsidian`) instead of a raw Tailwind color when styling new markup. The provider accent tokens intentionally mirror the app's `ProviderTint` values (`LocalProvider` = green, `RemindersProvider` = orange, `ObsidianProvider` = purple).

The brand red and leaf green each ship in two variants, and picking the wrong one silently fails WCAG AA:

| Token | Contrast on canvas | Use for |
| --- | --- | --- |
| `brand` (`#E9342B`) | 3.9:1 — **fails AA for text** | focus ring, underline decoration, tints |
| `brand-ink` (`#CE2E25`) | 4.9:1 (5.2:1 against white) | link text, filled CTA backgrounds |
| `leaf` (`#2F8F46`) | 3.8:1 — **fails AA for text** | privacy band tints and borders |
| `leaf-ink` (`#26773C`) | 5.2:1 | privacy headings and callout text |

Anything a visitor reads uses the `-ink` variant. The design plan specifies the brand values as approximate, so these darkened pairs stay inside its direction while meeting the accessibility bar it also requires.

The site is light-only by design — the dark app screenshots are the intended contrast event — so there is no dark-mode variant to maintain.

### Screenshots

`Screenshot.astro` looks up each capture by filename via `import.meta.glob('../assets/screenshots/*.png', { eager: true })`. Dropping a correctly named PNG into `site/src/assets/screenshots/` is the entire integration — no code change, no import to add. Until a file lands, the component renders a labeled placeholder so the build stays green.

The lookup is by exact filename, so these cannot be renamed without editing the section component that requests them:

| File | Capture |
| --- | --- |
| `hero-timer.png` | Timer screen, running session, sidebar visible |
| `menu-bar-timer.png` | Popover open, selected task, active controls |
| `task-providers.png` | Task view with all three sources in the sidebar |
| `task-editing.png` | Edit sheet over the main window, seeded task |
| `stats-today.png` | Today view, summary cards, task breakdown donut |

Capture in dark mode at one display scale, from a seeded workspace only — never real task data. Stats is captured on **Today** and no other scope: the session store holds every session ever recorded, so 7 Days, This Month, and All Time would publish real task titles.

Astro emits an optimized WebP derivative for each at build time, which is what visitors download; the committed PNG masters affect repository size only.

### App Store flip

`site/src/utils/site.ts` holds two intentionally `null` switches:

- `APP_STORE_URL` — once the Mac App Store listing resolves publicly, set this to the listing URL. `DownloadActions.astro` then promotes the App Store badge to primary and demotes the direct DMG download to secondary automatically.
- `SOCIAL_IMAGE` — once `site/public/og.png` (1200×630) is composed from the sanitized screenshot set, set this to `/og.png`. `Base.astro` then starts rendering `og:image`/`twitter:image` tags.

Both are single-line changes; no other file needs editing.
