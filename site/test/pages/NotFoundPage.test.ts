import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import NotFoundPage from '../../src/pages/404.astro'

describe('not found page', () => {
  let html: string

  const getHtml = async () => {
    if (html) return html
    const container = await AstroContainer.create()
    html = await container.renderToString(NotFoundPage)
    return html
  }

  it('points visitors at the privacy and support pages', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('/privacy')
    expect(rendered).toContain('/support')
  })

  it('renders the shared footer', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('<footer')
    expect(rendered).toContain('Richard Klein')
  })
})
