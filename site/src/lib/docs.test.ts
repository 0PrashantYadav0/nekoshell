import { describe, expect, it } from 'vitest'
import rehypeSlug from 'rehype-slug'
import {
  bodyOf,
  docsHref,
  groups,
  headingSlug,
  headingsOf,
  pageBySlug,
  pages,
  plain,
  repoBlob,
  slugOf,
  sourceOf,
  titleOf,
} from './docs'

type Heading = { properties: { id?: string } }

/** The ids rehype-slug itself writes for a run of headings, given the text
 *  each one renders to. This is the yardstick headingsOf has to agree with:
 *  the plugin is run over a tree built by hand, so the comparison is about the
 *  slugging and the numbering and nothing else. */
function rehypeIds(headings: [number, string][]): string[] {
  const tree = {
    type: 'root',
    children: headings.map(([depth, text]) => ({
      type: 'element',
      tagName: `h${depth}`,
      properties: {} as { id?: string },
      children: [{ type: 'text', value: text }],
    })),
  }
  const transform = rehypeSlug() as unknown as (t: unknown) => void
  transform(tree)
  return tree.children.map((h: Heading) => h.properties.id ?? '')
}

describe('slugOf', () => {
  it('lower-cases the file name and drops the extension', () => {
    expect(slugOf('INSTALL.md')).toBe('install')
    expect(slugOf('CONFIGURATION.md')).toBe('configuration')
  })

  it('lets an index or a README stand for its directory', () => {
    expect(slugOf('index.md')).toBe('')
    expect(slugOf('plugins/README.md')).toBe('plugins')
    expect(slugOf('plugins/index.md')).toBe('plugins')
  })

  it('keeps the directory in front of the name', () => {
    expect(slugOf('plugins/ARCHITECTURE.md')).toBe('plugins/architecture')
    expect(slugOf('terminals/terminal-app.md')).toBe('terminals/terminal-app')
  })
})

describe('headingSlug and plain', () => {
  it('slugs a heading the way github-slugger does', () => {
    expect(headingSlug('Upgrading')).toBe('upgrading')
    expect(headingSlug('nekoshell.toml')).toBe('nekoshelltoml')
    expect(headingSlug('What you get')).toBe('what-you-get')
  })

  it('takes the inline Markdown off a heading', () => {
    expect(plain('`nekoshell doctor`')).toBe('nekoshell doctor')
    expect(plain('See [INSTALL.md](INSTALL.md)')).toBe('See INSTALL.md')
    expect(plain('**Upgrading**')).toBe('Upgrading')
    expect(plain('_Upgrading_')).toBe('Upgrading')
    expect(plain('*Upgrading*')).toBe('Upgrading')
    expect(plain('~~Gone~~')).toBe('Gone')
  })

  it('leaves an underscore inside a word alone', () => {
    expect(plain('local_zsh and greet_conf')).toBe('local_zsh and greet_conf')
    expect(headingSlug(plain('local_zsh'))).toBe('local_zsh')
  })
})

describe('headingsOf', () => {
  it('agrees with rehype-slug when a heading repeats', () => {
    const ids = headingsOf('## Upgrading\n\nwords\n\n## Upgrading\n').map((h) => h.id)
    expect(ids).toEqual(rehypeIds([[2, 'Upgrading'], [2, 'Upgrading']]))
    expect(ids).toEqual(['upgrading', 'upgrading-1'])
  })

  it('counts every heading depth, not only the two it shows', () => {
    // rehype-slug numbers across all depths, so the h4 takes the bare slug and
    // the h2 the suffix. A scan of h2 and h3 alone would give the h2 "options".
    expect(rehypeIds([[4, 'Options'], [2, 'Options']])).toEqual(['options', 'options-1'])
    expect(headingsOf('#### Options\n\n## Options\n').map((h) => h.id)).toEqual(['options-1'])
  })

  it('slugs an emphasised heading to the plain word', () => {
    const headings = headingsOf('## _Upgrading_\n')
    expect(headings.map((h) => h.id)).toEqual(rehypeIds([[2, 'Upgrading']]))
    expect(headings[0].text).toBe('Upgrading')
  })

  it('ignores a heading inside a fenced code block', () => {
    const md = '## Real\n\n```sh\n## not a heading\n```\n\n## Real\n'
    expect(headingsOf(md).map((h) => h.id)).toEqual(['real', 'real-1'])
  })

  it('does not let the stripped title heading take a slug', () => {
    // The article prints the h1 itself, so the renderer never sees it and
    // rehype-slug never counts it.
    expect(headingsOf(bodyOf('# Install\n\n## Install\n')).map((h) => h.id)).toEqual(['install'])
  })

  it('reads a title through its inline Markdown', () => {
    expect(titleOf('# `nekoshell` at a glance\n')).toBe('nekoshell at a glance')
  })
})

describe('sourceOf', () => {
  it('names the repository file each copy came from', () => {
    expect(sourceOf('index.md')).toBe('docs/README.md')
    expect(sourceOf('INSTALL.md')).toBe('docs/INSTALL.md')
    expect(sourceOf('plugins/index.md')).toBe('docs/plugins/README.md')
    expect(sourceOf('plugins/tmux.md')).toBe('docs/plugins/tmux.md')
    expect(sourceOf('terminals/kitty.md')).toBe('terminals/kitty/README.md')
    expect(sourceOf('changelog.md')).toBe('CHANGELOG.md')
    expect(sourceOf('third-party.md')).toBe('THIRD_PARTY.md')
  })
})

describe('docsHref', () => {
  const cases: [string, string, string][] = [
    ['docs/README.md', 'INSTALL.md', '/docs/install'],
    ['docs/README.md', 'plugins/README.md', '/docs/plugins'],
    ['docs/plugins/README.md', 'tmux.md', '/docs/plugins/tmux'],
    ['docs/README.md', 'plugins/tmux.md', '/docs/plugins/tmux'],
    ['docs/TERMINALS.md', '../terminals/kitty/README.md', '/docs/terminals/kitty'],
    ['docs/README.md', '../README.md', '/'],
    ['docs/README.md', '../README.md#screenshots', '/#greet'],
    ['docs/plugins/anime.md', '../../README.md#screenshots', '/#greet'],
    ['docs/README.md', '../CHANGELOG.md', '/docs/changelog'],
    ['docs/README.md', '../THIRD_PARTY.md', '/docs/third-party'],
    ['docs/plugins/README.md', 'ARCHITECTURE.md', '/docs/plugins/architecture'],
    ['docs/README.md', 'ARCHITECTURE.md', '/docs/architecture'],
    ['docs/README.md', 'INSTALL.md#upgrading', '/docs/install#upgrading'],
    ['docs/plugins/anime.md', '../screenshots/greet-anime.png', '/shots/greet-anime.png'],
  ]
  for (const [source, href, want] of cases) {
    it(`maps ${href} in ${source} to ${want}`, () => {
      expect(docsHref(href, source)).toEqual({ href: want, external: false })
    })
  }

  it('leaves an absolute link external', () => {
    const link = docsHref('https://github.com/0PrashantYadav0/nekoshell', 'docs/README.md')
    expect(link).toEqual({ href: 'https://github.com/0PrashantYadav0/nekoshell', external: true })
  })

  it('sends a repository-only page to GitHub', () => {
    expect(docsHref('contributing/testing.md', 'docs/README.md')).toEqual({
      href: `${repoBlob}/docs/contributing/testing.md`,
      external: true,
    })
  })

  it('keeps an in-page fragment as it is', () => {
    expect(docsHref('#upgrading', 'docs/INSTALL.md')).toEqual({ href: '#upgrading', external: false })
  })

  it('drops a link with a scheme that is not the web', () => {
    expect(docsHref('javascript:alert(1)', 'docs/README.md')).toEqual({ href: '', external: false })
  })
})

describe('the page list', () => {
  it('groups the sidebar in the order docs/README.md reads in', () => {
    expect(groups.map((g) => g.label)).toEqual(['Start here', 'Plugins', 'Terminals', 'Under the hood', 'Project'])
  })

  it('opens "Start here" with the index and closes "Project" with the licences', () => {
    expect(groups[0].pages.map((p) => p.slug)).toEqual(['', 'install', 'configuration', 'terminals', 'remote'])
    expect(groups[4].pages.map((p) => p.slug)).toEqual(['changelog', 'third-party'])
  })

  it('puts the plugin index first, the plugin pages alphabetically, architecture last', () => {
    const slugs = groups[1].pages.map((p) => p.slug)
    expect(slugs[0]).toBe('plugins')
    expect(slugs[slugs.length - 1]).toBe('plugins/architecture')
    const middle = slugs.slice(1, -1)
    expect(middle).toEqual([...middle].sort())
    expect(middle).toContain('plugins/tmux')
  })

  it('lists the five adapters in the order TERMINALS.md introduces them', () => {
    expect(groups[2].pages.map((p) => p.slug)).toEqual([
      'terminals/iterm2',
      'terminals/kitty',
      'terminals/ghostty',
      'terminals/warp',
      'terminals/terminal-app',
    ])
  })

  it('gives every page a title and a body', () => {
    for (const page of pages) {
      expect(page.title, page.path).not.toBe('')
      expect(page.body.length, page.path).toBeGreaterThan(0)
    }
  })

  it('shows every Markdown file the glob finds', () => {
    const paths = Object.keys(import.meta.glob('../content/docs/**/*.md')).map((k) =>
      k.slice('../content/docs/'.length),
    )
    expect(paths.length).toBeGreaterThan(0)
    expect(pages).toHaveLength(paths.length)
    for (const path of paths) {
      const page = pageBySlug(slugOf(path))
      expect(page?.title, path).toBeTruthy()
    }
  })
})
