import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import Header from '../../src/components/Header.astro'

describe('header', () => {
  it('marks the active route with aria-current="page"', async () => {
    const container = await AstroContainer.create()
    const html = await container.renderToString(Header, { props: { current: 'privacy' } })

    const privacyLink = html.match(/<a[^>]*href="[^"]*\/privacy"[^>]*>/)?.[0]

    expect(privacyLink).toContain('aria-current="page"')
  })

  it('does not mark inactive routes as current', async () => {
    const container = await AstroContainer.create()
    const html = await container.renderToString(Header, { props: { current: 'privacy' } })

    const homeLink = html.match(/<a[^>]*href="[^"]*\/"[^>]*>/)?.[0]
    const supportLink = html.match(/<a[^>]*href="[^"]*\/support"[^>]*>/)?.[0]

    expect(homeLink).not.toContain('aria-current')
    expect(supportLink).not.toContain('aria-current')
  })

  it('indicates the active route with more than color alone', async () => {
    const container = await AstroContainer.create()
    const html = await container.renderToString(Header, { props: { current: 'support' } })

    const supportLink = html.match(/<a[^>]*aria-current="page"[^>]*>/)?.[0]

    // The active link must carry a non-color signal (an underline class),
    // not rely on text color alone to convey state.
    expect(supportLink).toContain('underline')
  })

  it('renders no active indicator when current is not one of the nav routes', async () => {
    const container = await AstroContainer.create()
    const html = await container.renderToString(Header)

    expect(html).not.toContain('aria-current')
  })
})
