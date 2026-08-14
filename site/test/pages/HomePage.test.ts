import { DOWNLOAD_URL, HOME_TITLE, MINIMUM_MACOS, SITE_URL } from '@utils/site'
import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import HomePage from '../../src/pages/index.astro'

describe('home page', () => {
  let html: string

  const getHtml = async () => {
    if (html) return html
    const container = await AstroContainer.create()
    html = await container.renderToString(HomePage)
    return html
  }

  it('renders the hero headline', async () => {
    expect(await getHtml()).toContain('Focus where your tasks already live.')
  })

  it('renders the route metadata the design plan pins for home', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain(`<title>${HOME_TITLE}</title>`)
    expect(rendered).toContain(`rel="canonical" href="${SITE_URL}/"`)
  })

  it('renders no og:image tag while SOCIAL_IMAGE is null', async () => {
    expect(await getHtml()).not.toContain('og:image')
  })

  it('offers the direct DMG download and states the minimum macOS version', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain(DOWNLOAD_URL)
    expect(rendered).toContain(MINIMUM_MACOS)
  })

  it('names all three task providers', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('Local')
    expect(rendered).toContain('Apple Reminders')
    expect(rendered).toContain('Obsidian')
  })

  it('includes every section heading', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('Focus from the menu bar.')
    expect(rendered).toContain('Edit tasks in place.')
    expect(rendered).toContain('Automate with URLs.')
    expect(rendered).toContain('See where your focus goes.')
    expect(rendered).toContain('Ready to focus?')
  })

  it('renders the shared header and footer', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('<header')
    expect(rendered).toContain('<footer')
    expect(rendered).toContain('Richard Klein')
  })

  it('renders no App Store link while APP_STORE_URL is null', async () => {
    const rendered = await getHtml()

    expect(rendered).not.toContain('apps.apple.com')
    expect(rendered).not.toContain('Download on the App Store')
  })

  it('never makes a forbidden claim App Review would reject', async () => {
    // Home is the only route this guardrail applies to — privacy.astro
    // legitimately discusses a possible future Pro/iCloud tier under
    // "Future changes", which is exempt.
    const rendered = await getHtml()

    // Word-anchored on purpose: a bare /sync/ also matches the `async` in
    // Astro's `decoding="async"`, so it fired on every real screenshot.
    expect(rendered).not.toMatch(
      /\biCloud\b|\bsync(s|ed|ing)?\b|\bTaskmato Pro\b|\bcloud provider|\bacross (your )?Macs\b/i
    )
  })
})
