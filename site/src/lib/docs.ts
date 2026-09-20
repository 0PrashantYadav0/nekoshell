// The documentation the site renders at /docs. The Markdown lives under
// src/content/docs/ as committed copies of the repository's pages, refreshed
// by scripts/sync-docs.mjs; this module reads them all once, works out each
// page's slug, title, group and headings, and maps the relative links the
// Markdown carries onto the site's routes.
//
// Only the lazily loaded /docs route imports this module, so none of it
// reaches the landing page's bundle.

import GithubSlugger, { slug } from 'github-slugger'

export type Heading = { depth: 2 | 3; id: string; text: string }

export type DocPage = {
  /** Path under src/content/docs, e.g. "plugins/tmux.md". */
  path: string
  /** Route slug without the /docs prefix; "" is the index. */
  slug: string
  /** Full route, e.g. "/docs/plugins/tmux". */
  route: string
  title: string
  /** The file's path in the repository, for the "edit this page" link. */
  source: string
  headings: Heading[]
  /** The Markdown below the title, which the article renders as its own h1. */
  body: string
}

export type DocGroup = { label: string; pages: DocPage[] }

const files = import.meta.glob('../content/docs/**/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>

const prefix = '../content/docs/'

/** The slug of a file under src/content/docs: the lower-case name without
 *  its extension, with an index (or a README) standing for its directory. */
export function slugOf(path: string): string {
  const parts = path.split('/')
  const name = parts.pop()!.replace(/\.md$/, '')
  const dir = parts.join('/').toLowerCase()
  if (name === 'index' || name === 'README') return dir
  return [dir, name.toLowerCase()].filter(Boolean).join('/')
}

/** Where a file under src/content/docs came from in the repository. */
export function sourceOf(path: string): string {
  if (path === 'changelog.md') return 'CHANGELOG.md'
  if (path === 'third-party.md') return 'THIRD_PARTY.md'
  if (path === 'index.md') return 'docs/README.md'
  if (path === 'plugins/index.md') return 'docs/plugins/README.md'
  const terminal = /^terminals\/([^/]+)\.md$/.exec(path)
  if (terminal) return `terminals/${terminal[1]}/README.md`
  return `docs/${path}`
}

/** The id rehype-slug would give a heading standing on its own. rehype-slug
 *  slugs with github-slugger, so this module calls the same package rather
 *  than keeping a copy of its rules: a copy that drifted would leave the
 *  table of contents pointing at ids no heading carries. */
export function headingSlug(text: string): string {
  return slug(text)
}

/** A heading's text as the renderer shows it, because github-slugger is given
 *  a heading's text content rather than its Markdown source. An underscore is
 *  emphasis only at a word boundary, so `local_zsh` keeps its own. */
export function plain(text: string): string {
  return text
    .replace(/`/g, '')
    .replace(/!?\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/__([^_]+)__/g, '$1')
    .replace(/~~([^~]+)~~/g, '$1')
    .replace(/(?<![\w*])\*([^*]+)\*(?![\w*])/g, '$1')
    .replace(/(?<![\w_])_([^_]+)_(?![\w_])/g, '$1')
    .trim()
}

/** Every line of a file that is a heading, skipping fenced code. */
function scanHeadings(md: string, depths: number[]): { depth: number; text: string }[] {
  const found: { depth: number; text: string }[] = []
  let fence = ''
  for (const line of md.split('\n')) {
    const open = /^\s*(```+|~~~+)/.exec(line)
    if (open) {
      if (!fence) fence = open[1][0]
      else if (line.trimStart().startsWith(fence)) fence = ''
      continue
    }
    if (fence) continue
    const head = /^(#{1,6})\s+(.*)$/.exec(line)
    if (head && depths.includes(head[1].length)) found.push({ depth: head[1].length, text: plain(head[2]) })
  }
  return found
}

export function titleOf(md: string): string {
  return scanHeadings(md, [1])[0]?.text ?? ''
}

/** The file without its title heading: the article prints that itself. */
export function bodyOf(md: string): string {
  return md.replace(/^\s*#\s+.*(\r?\n)+/, '')
}

/** The h2 and h3 of a page, with the ids rehype-slug will write.
 *
 *  Give it the Markdown that is actually rendered — `bodyOf(raw)`, not the raw
 *  file — and it walks every heading depth in document order, because
 *  github-slugger numbers a repeated slug (`-1`, `-2`) across all of them. A
 *  scan of h2 and h3 alone would count differently as soon as an h1 or an h4
 *  shared a heading's text. */
export function headingsOf(rendered: string): Heading[] {
  const slugger = new GithubSlugger()
  const found: Heading[] = []
  for (const { depth, text } of scanHeadings(rendered, [1, 2, 3, 4, 5, 6])) {
    const id = slugger.slug(text)
    if (depth === 2 || depth === 3) found.push({ depth, text, id })
  }
  return found
}

const byPath = new Map<string, DocPage>()
for (const [key, raw] of Object.entries(files)) {
  const path = key.slice(prefix.length)
  const pageSlug = slugOf(path)
  // The article renders the title itself, so the h1 never reaches the
  // renderer; the headings are read from what does.
  const body = bodyOf(raw)
  byPath.set(path, {
    path,
    slug: pageSlug,
    route: pageSlug ? `/docs/${pageSlug}` : '/docs',
    title: titleOf(raw),
    source: sourceOf(path),
    headings: headingsOf(body),
    body,
  })
}

const bySlug = new Map<string, DocPage>()
for (const page of byPath.values()) bySlug.set(page.slug, page)

const pick = (slugs: string[]): DocPage[] => slugs.map((s) => bySlug.get(s)).filter((p): p is DocPage => !!p)

const pluginSlugs = [...bySlug.keys()]
  .filter((s) => s.startsWith('plugins/') && s !== 'plugins/architecture')
  .sort()

// The five adapters in the order docs/TERMINALS.md introduces them.
const terminalSlugs = ['iterm2', 'kitty', 'ghostty', 'warp', 'terminal-app'].map((id) => `terminals/${id}`)

/** The sidebar, in the order and with the labels docs/README.md groups by. */
export const groups: DocGroup[] = [
  { label: 'Start here', pages: pick(['', 'install', 'configuration', 'terminals', 'remote']) },
  { label: 'Plugins', pages: pick(['plugins', ...pluginSlugs, 'plugins/architecture']) },
  { label: 'Terminals', pages: pick(terminalSlugs) },
  { label: 'Under the hood', pages: pick(['architecture', 'distribution']) },
  { label: 'Project', pages: pick(['changelog', 'third-party']) },
].filter((g) => g.pages.length > 0)

/** Every page, in sidebar order: what previous and next walk. */
export const pages: DocPage[] = groups.flatMap((g) => g.pages)

export function pageBySlug(slug: string): DocPage | undefined {
  return bySlug.get(slug.replace(/^\/+|\/+$/g, '').toLowerCase())
}

export const repoBlob = 'https://github.com/0PrashantYadav0/nekoshell/blob/main'

// The front page's anchors that the landing page gives another name.
const landingAnchors: Record<string, string> = { screenshots: 'greet' }

/** Resolve a relative path against a directory, the way a browser would. */
function resolvePath(dir: string, rel: string): string {
  const parts = dir ? dir.split('/') : []
  for (const seg of rel.split('/')) {
    if (seg === '' || seg === '.') continue
    else if (seg === '..') parts.pop()
    else parts.push(seg)
  }
  return parts.join('/')
}

export type DocLink = { href: string; external: boolean }

/** Where a repository path is served on the site: a docs route when the page
 *  ships, the landing page for the front README, /shots for a screenshot, and
 *  GitHub for everything that is repository-only. */
function routeFor(path: string, hash: string): DocLink {
  if (path === 'README.md') {
    const id = hash.slice(1)
    return { href: `/${id ? `#${landingAnchors[id] ?? id}` : ''}`, external: false }
  }
  const shot = /^docs\/screenshots\/(.+)$/.exec(path)
  if (shot) return { href: `/shots/${shot[1]}`, external: false }
  let slug: string | null = null
  if (path === 'CHANGELOG.md') slug = 'changelog'
  else if (path === 'THIRD_PARTY.md') slug = 'third-party'
  else if (path.startsWith('docs/') && path.endsWith('.md')) slug = slugOf(path.slice('docs/'.length))
  else {
    const terminal = /^terminals\/([^/]+)\/README\.md$/.exec(path)
    if (terminal) slug = `terminals/${terminal[1]}`
  }
  const page = slug === null ? undefined : bySlug.get(slug)
  if (!page) return { href: `${repoBlob}/${path}${hash}`, external: true }
  return { href: `${page.route}${hash}`, external: false }
}

/** Map a link or an image source written in the Markdown of `source` onto the
 *  address the site serves it at. */
export function docsHref(href: string, source: string): DocLink {
  if (!href) return { href: '', external: false }
  if (href.startsWith('#') || href.startsWith('/')) return { href, external: false }
  const scheme = /^([a-z][a-z0-9+.-]*):/i.exec(href)
  if (scheme) {
    const ok = /^(https?|mailto)$/i.test(scheme[1])
    return { href: ok ? href : '', external: ok }
  }
  const cut = href.indexOf('#')
  const path = cut === -1 ? href : href.slice(0, cut)
  const hash = cut === -1 ? '' : href.slice(cut)
  const dir = source.split('/').slice(0, -1).join('/')
  return routeFor(resolvePath(dir, path), hash)
}
