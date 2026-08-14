/** The support mailbox used across the privacy and support pages. */
export const SUPPORT_EMAIL = 'support@taskmato.com'

/** The public GitHub repository for Taskmato. */
export const REPO_URL = 'https://github.com/richwklein/taskmato'

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
