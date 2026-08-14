import { ISSUES_URL, SUPPORT_EMAIL } from '@utils/site'
import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import SupportPage from '../../src/pages/support.astro'

describe('support page', () => {
  let html: string

  const getHtml = async () => {
    if (html) return html
    const container = await AstroContainer.create()
    html = await container.renderToString(SupportPage)
    return html
  }

  it('offers both the support email and the issue tracker as contact paths', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain(SUPPORT_EMAIL)
    expect(rendered).toContain(ISSUES_URL)
  })

  it('links back to the privacy page', async () => {
    expect(await getHtml()).toContain('/privacy')
  })

  it('presents each common question as a disclosure element', async () => {
    const rendered = await getHtml()

    expect(rendered.match(/<details/g)).toHaveLength(5)
    expect(rendered.match(/<summary/g)).toHaveLength(5)
  })

  it('keeps the answer text in the markup so collapsed answers stay findable', async () => {
    // <details> content ships in the HTML regardless of open state, so search
    // engines and App Review can still read it.
    expect(await getHtml()).toContain('Privacy & Security → Reminders')
  })

  it('leads with the topic rows from the concept', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('How can we help?')
    expect(rendered).toContain('Contact us')
    expect(rendered).toContain('Report an issue')
  })

  it('opens off-site destinations in a new tab, safely and audibly', async () => {
    const rendered = await getHtml()

    // Every target="_blank" needs noopener/noreferrer, and a sighted-only cue
    // would leave screen reader users with no warning that focus moved.
    const blankLinks = rendered.match(/<a[^>]*target="_blank"[^>]*>/g) ?? []

    expect(blankLinks.length).toBeGreaterThan(0)
    for (const link of blankLinks) {
      expect(link).toContain('rel="noopener noreferrer"')
    }
    expect(rendered).toContain('(opens in a new tab)')
  })

  it('keeps same-site links in the current tab', async () => {
    const rendered = await getHtml()

    const privacyLink = rendered.match(/<a[^>]*href="[^"]*\/privacy"[^>]*>/)?.[0]
    const mailLink = rendered.match(/<a[^>]*href="mailto:[^"]*"[^>]*>/)?.[0]

    expect(privacyLink).not.toContain('target')
    expect(mailLink).not.toContain('target')
  })

  it('never offers a knowledge base it does not have', async () => {
    // The concept's third row was "Get help — browse guides and troubleshooting
    // articles". No such thing exists, and the design plan forbids implying one.
    const rendered = await getHtml()

    expect(rendered).not.toMatch(/knowledge base|troubleshooting articles|browse guides/i)
  })

  it('renders the shared header and footer', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('<header')
    expect(rendered).toContain('<footer')
    expect(rendered).toContain('Richard Klein')
  })

  it('marks support as the active header route', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('aria-current="page"')
  })
})
