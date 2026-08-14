import { SUPPORT_EMAIL } from '@utils/site'
import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import PrivacyPage from '../../src/pages/privacy.astro'

describe('privacy page', () => {
  let html: string

  const getHtml = async () => {
    if (html) return html
    const container = await AstroContainer.create()
    html = await container.renderToString(PrivacyPage)
    return html
  }

  it('gives the support email as the contact path', async () => {
    expect(await getHtml()).toContain(SUPPORT_EMAIL)
  })

  it('numbers every policy section', async () => {
    const rendered = await getHtml()

    // The concept numbers the sections so the page scans as a policy document.
    expect(rendered).toContain('1. What Taskmato stores on your Mac')
    expect(rendered).toContain('7. Contact')
  })

  it('links to the support page', async () => {
    expect(await getHtml()).toContain('/support')
  })

  it('renders the shared header and footer', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('<header')
    expect(rendered).toContain('<footer')
    expect(rendered).toContain('Richard Klein')
  })

  it('marks privacy as the active header route', async () => {
    const rendered = await getHtml()

    expect(rendered).toContain('aria-current="page"')
  })
})
