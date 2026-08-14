/**
 * Hand-authored stroke icons in the SF Symbols idiom: 24px grid, 1.75 stroke,
 * round caps and joins, drawn in `currentColor` so a parent's text color tints
 * them. Inline rather than a dependency — the site ships no external requests,
 * and the set is small enough that a library would cost more than it saves.
 *
 * Deliberately generic: no third-party marks. The provider icons describe what
 * each source *is* (a list, a checklist, a note), never its brand.
 *
 * Each value is the inner markup of a `0 0 24 24` `<svg>`; `Icon.astro` supplies
 * the wrapper and its stroke attributes.
 */
export const ICONS = {
  tray: `<path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><path d="M22 12h-6l-2 3h-4l-2-3H2"/>`,
  checklist: `<path d="M10 6h11M10 12h11M10 18h11"/><path d="M3 6.2l1.3 1.3 2.7-2.7"/><path d="M3 12.2l1.3 1.3 2.7-2.7"/><path d="M3 18.2l1.3 1.3 2.7-2.7"/>`,
  'doc-text': `<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h4"/>`,
  link: `<path d="M10.5 13.2a4.8 4.8 0 0 0 7 .3l2.8-2.8a4.8 4.8 0 0 0-6.8-6.8l-1.6 1.6"/><path d="M13.5 10.8a4.8 4.8 0 0 0-7-.3l-2.8 2.8a4.8 4.8 0 0 0 6.8 6.8l1.6-1.6"/>`,
  lock: `<rect x="4" y="10.5" width="16" height="10" rx="2"/><path d="M8 10.5V7a4 4 0 0 1 8 0v3.5"/>`,
  'shield-check': `<path d="M12 3l7.5 3v5.2c0 4.6-3.1 8.5-7.5 10.3-4.4-1.8-7.5-5.7-7.5-10.3V6z"/><path d="M9 12l2.2 2.2L15.2 10"/>`,
  folder: `<path d="M3 7a2 2 0 0 1 2-2h3.7a2 2 0 0 1 1.4.6L11.7 7H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>`,
  key: `<circle cx="7.5" cy="15.5" r="4.5"/><path d="M10.7 12.3 21 2"/><path d="M17.2 5.8l2.5 2.5"/><path d="M14.4 8.6l2.5 2.5"/>`,
  'eye-off': `<path d="M9.9 5.2A9.6 9.6 0 0 1 12 5c5 0 9 4.1 9 7 0 1-.6 2.3-1.7 3.5"/><path d="M6.6 7C4.2 8.5 3 10.7 3 12c0 2.9 4 7 9 7 1.4 0 2.7-.3 3.9-.8"/><path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"/><path d="m3 3 18 18"/>`,
  'alert-triangle': `<path d="M10.3 4.4 2.7 17.6a2 2 0 0 0 1.7 3h15.2a2 2 0 0 0 1.7-3L13.7 4.4a2 2 0 0 0-3.4 0z"/><path d="M12 9.5v4"/><circle cx="12" cy="17" r="1" fill="currentColor" stroke="none"/>`,
  trash: `<path d="M3.5 6.5h17"/><path d="M9 6.5V5a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 5v1.5"/><path d="M18.4 6.5 17.7 19a2 2 0 0 1-2 1.9H8.3a2 2 0 0 1-2-1.9L5.6 6.5"/><path d="M10 11v5.5M14 11v5.5"/>`,
  'question-circle': `<circle cx="12" cy="12" r="9"/><path d="M9.4 9.4a2.7 2.7 0 0 1 5.2.9c0 1.8-2.6 2.2-2.6 3.9"/><circle cx="12" cy="17.2" r="1" fill="currentColor" stroke="none"/>`,
  envelope: `<rect x="2.5" y="5" width="19" height="14" rx="2"/><path d="m3.6 7 7.3 5.2a2 2 0 0 0 2.2 0L20.4 7"/>`,
  lightbulb: `<path d="M9.2 18h5.6"/><path d="M10.2 21h3.6"/><path d="M12 3a6 6 0 0 0-3.6 10.8c.6.5 1 1.2 1.1 1.9l.1.8h4.8l.1-.8c.1-.7.5-1.4 1.1-1.9A6 6 0 0 0 12 3z"/>`,
  laptop: `<path d="M5 5.6A1.6 1.6 0 0 1 6.6 4h10.8A1.6 1.6 0 0 1 19 5.6V15H5z"/><path d="M2.5 15h19l-1.1 2.9a1.6 1.6 0 0 1-1.5 1H5.1a1.6 1.6 0 0 1-1.5-1z"/>`,
  download: `<path d="M12 3.5v11"/><path d="m7.5 10.5 4.5 4.5 4.5-4.5"/><path d="M4.5 17v1.5a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V17"/>`,
  plus: `<path d="M12 5.5v13M5.5 12h13"/>`,
  check: `<path d="m4.5 12.6 5 5 10-11"/>`,
} as const

/** Every icon name `Icon.astro` accepts. */
export type IconName = keyof typeof ICONS
