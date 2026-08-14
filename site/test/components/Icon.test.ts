import { ICONS } from '@utils/icons'
import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import Icon from '../../src/components/Icon.astro'

const render = async (props: Record<string, unknown>) => {
  const container = await AstroContainer.create()
  return container.renderToString(Icon, { props })
}

describe('icon', () => {
  it('hides decorative icons from assistive technology by default', async () => {
    const html = await render({ name: 'lock' })

    expect(html).toContain('aria-hidden="true"')
    expect(html).not.toContain('role="img"')
  })

  it('exposes an accessible name when one is given', async () => {
    const html = await render({ name: 'lock', label: 'Private' })

    expect(html).toContain('role="img"')
    expect(html).toContain('aria-label="Private"')
    expect(html).not.toContain('aria-hidden')
  })

  it('inherits its color from the parent so tokens can tint it', async () => {
    const html = await render({ name: 'check' })

    expect(html).toContain('stroke="currentColor"')
    expect(html).toContain('fill="none"')
  })

  // Guards against a truncated or misnamed path list slipping in — an icon
  // that fails this renders as an empty box on the page.
  it.each(Object.keys(ICONS))('renders %s as well-formed svg markup', async (name) => {
    const html = await render({ name })

    expect(html).toMatch(/<svg[\s\S]+<\/svg>/)
    expect(html).toMatch(/<(path|circle|rect)\b/)
    expect(html).not.toContain('undefined')
  })
})
