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

  it('renders the shared footer', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('<footer')
    expect(rendered).toContain('Richard Klein')
  })
})
