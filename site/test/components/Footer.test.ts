import { REPO_URL } from '@utils/site'
import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import Footer from '../../src/components/Footer.astro'

describe('footer', () => {
  let html: string

  const getHtml = async () => {
    if (html) return html
    const container = await AstroContainer.create()
    html = await container.renderToString(Footer)
    return html
  }

  it('carries the brand mark alongside the navigation', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('Taskmato')
    expect(rendered).toContain('<nav')
  })

  it('keeps all four navigation destinations the design plan requires', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('href="/"')
    expect(rendered).toContain('/privacy')
    expect(rendered).toContain('/support')
    expect(rendered).toContain(REPO_URL)
  })

  it('renders the copyright line', async () => {
    expect(await getHtml()).toContain('Richard Klein')
  })

  it('leaves the brand image out of the accessibility tree', async () => {
    // The wordmark beside it already names the link — an alt here would make
    // screen readers announce "Taskmato" twice.
    expect(await getHtml()).toContain('alt=""')
  })
})
