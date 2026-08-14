/** The support mailbox used across the privacy and support pages. */
export const SUPPORT_EMAIL = 'support@taskmato.com'

/** The public GitHub repository for Taskmato. */
export const REPO_URL = 'https://github.com/richwklein/taskmato'

/** The site's canonical origin, matching `astro.config.ts`'s `site` value. */
export const SITE_URL = 'https://taskmato.com'

/**
 * The Mac App Store listing URL. `null` until the listing resolves publicly —
 * flip this one line to promote the App Store badge to primary in
 * `DownloadActions.astro` and start rendering the button.
 */
export const APP_STORE_URL: string | null = null

/**
 * Root-relative path to the 1200×630 Open Graph image, once composed from the
 * sanitized screenshot captures. `null` until `site/public/og.png` lands —
 * flip this one line to start rendering `og:image`/`twitter:image` tags.
 */
export const SOCIAL_IMAGE: string | null = null

/** The public issue tracker, prefilled to the template picker. */
export const ISSUES_URL = `${REPO_URL}/issues/new/choose`

/** The GitHub Releases page, listing every published build. */
export const RELEASES_URL = `${REPO_URL}/releases`

/** Direct download link for the latest signed and notarized build. */
export const DOWNLOAD_URL = `${RELEASES_URL}/latest/download/Taskmato.dmg`

/** The minimum supported macOS version, matching `MACOSX_DEPLOYMENT_TARGET`. */
export const MINIMUM_MACOS = 'macOS 15 (Sequoia) or later'

/** Where the app's sandboxed data lives on disk, under the user's home directory. */
export const CONTAINER_PATH = '~/Library/Containers/com.richwklein.Taskmato/'

/** One-line description of the app, reused across page `<meta description>` tags. */
export const TAGLINE =
  'A native macOS menu bar Pomodoro timer that meets you wherever your tasks already live.'

/** Date the privacy policy was last revised, in `YYYY-MM-DD` form. */
export const POLICY_UPDATED = '2026-08-13'

/** `<title>` for the home route. */
export const HOME_TITLE = 'Taskmato — Focus where your tasks already live'

/** `<meta description>` for the home route. */
export const HOME_DESCRIPTION = TAGLINE

/** `<title>` for the privacy route. */
export const PRIVACY_TITLE = 'Privacy Policy — Taskmato'

/** `<meta description>` for the privacy route. */
export const PRIVACY_DESCRIPTION =
  "Taskmato's privacy policy: what the app stores, what it can access, and how it handles your data."

/** `<title>` for the support route. */
export const SUPPORT_TITLE = 'Support — Taskmato'

/** `<meta description>` for the support route. */
export const SUPPORT_DESCRIPTION =
  'Get help with Taskmato: contact support, report bugs, and find answers.'

/** `<title>` for the 404 route. */
export const NOT_FOUND_TITLE = 'Page not found — Taskmato'

/** `<meta description>` for the 404 route. */
export const NOT_FOUND_DESCRIPTION = "This page doesn't exist."

/**
 * Prefixes a root-relative path with the site's base URL, matching the
 * `.replace(/\/$/, '')` idiom already used in `Base.astro` and `index.astro`.
 * Keeps internal links correct if the site is ever served from a subpath.
 */
export function withBase(path: string): string {
  const base = import.meta.env.BASE_URL.replace(/\/$/, '')
  const suffix = path.startsWith('/') ? path : `/${path}`
  return `${base}${suffix}`
}

/**
 * Formats a date-only ISO string (`YYYY-MM-DD`) as a long-form English date,
 * pinned to UTC so the day never renders one day early west of Greenwich.
 */
export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  })
}
