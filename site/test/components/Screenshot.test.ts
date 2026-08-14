import { experimental_AstroContainer as AstroContainer } from 'astro/container'
import { describe, expect, it } from 'vitest'

import Screenshot from '../../src/components/Screenshot.astro'

const render = async (props: Record<string, unknown>) => {
  const container = await AstroContainer.create()
  return container.renderToString(Screenshot, { props })
}

describe('screenshot', () => {
  // Deliberately a name that will never exist under src/assets/screenshots/.
  // Using a real capture filename here breaks the moment that file lands.
  const missing = {
    filename: '__absent-capture__.png',
    alt: 'A capture that has not been taken yet',
    width: 1440,
    height: 900,
  }

  it('renders an accessible placeholder when the file is not present', async () => {
    const html = await render(missing)

    expect(html).toContain('Screenshot pending')
    expect(html).toContain('role="img"')
    expect(html).toContain(`aria-label="${missing.alt}"`)
  })

  it('does not render an <img> tag when the file is not present', async () => {
    expect(await render(missing)).not.toContain('<img')
  })

  it('holds the declared aspect ratio while the capture is pending', async () => {
    // Without this the placeholder collapses and the page reflows when the
    // real image lands.
    expect(await render(missing)).toContain('aspect-ratio: 1440 / 900')
  })

  it('renders a real capture as an optimized image', async () => {
    const html = await render({
      filename: 'hero-timer.png',
      alt: 'Taskmato timer running beside Local, Reminders, Obsidian, and Stats navigation',
      width: 1440,
      height: 1158,
    })

    expect(html).toContain('<img')
    expect(html).toContain('f=webp')
    expect(html).not.toContain('Screenshot pending')
  })

  it('constrains a real capture to its container', async () => {
    // A 1440px-wide source with no width constraint overflows its grid column
    // and scrolls the whole page sideways.
    const html = await render({
      filename: 'hero-timer.png',
      alt: 'Taskmato timer',
      width: 1440,
      height: 1158,
    })

    expect(html).toContain('h-auto')
    expect(html).toContain('w-full')
  })
})
