#!/usr/bin/env node
// sync-docs.mjs: copy the repository's user documentation into the site.
//
// The copies under src/content/docs/ and the screenshots under public/shots/
// are committed, not generated at deploy time. Vercel builds the site with
// Root Directory `site`, so the rest of the repository is not on disk there
// and nothing under src/ may reach outside `site/` at build time. This script
// refreshes the copies when the repository is present (a checkout, `prebuild`
// on a laptop, `npm run sync-docs` by hand) and prints one line and exits 0
// when it is not.
//
// Which files ship is decided by AGENTS.md, section "Docs": the pages a user
// reads. Contributor-only paths (docs/contributing/, docs/ci-checks/,
// docs/ai/, docs/superpowers/) stay on GitHub and are linked by URL.

import { existsSync, mkdirSync, readdirSync, copyFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const site = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const repo = resolve(site, '..')
const content = join(site, 'src', 'content', 'docs')
const shots = join(site, 'public', 'shots')

if (!existsSync(join(repo, 'docs'))) {
  console.log('sync-docs: no repository above site/, keeping the committed copies')
  process.exit(0)
}

// The five terminal adapters, by the id their directory carries.
const terminals = ['iterm2', 'kitty', 'ghostty', 'warp', 'terminal-app']

/** @type {[string, string][]} source in the repository, destination under src/content/docs */
const files = [
  ['docs/README.md', 'index.md'],
  ['docs/INSTALL.md', 'INSTALL.md'],
  ['docs/CONFIGURATION.md', 'CONFIGURATION.md'],
  ['docs/TERMINALS.md', 'TERMINALS.md'],
  ['docs/REMOTE.md', 'REMOTE.md'],
  ['docs/ARCHITECTURE.md', 'ARCHITECTURE.md'],
  ['docs/DISTRIBUTION.md', 'DISTRIBUTION.md'],
  ['docs/plugins/README.md', 'plugins/index.md'],
  ['docs/plugins/ARCHITECTURE.md', 'plugins/ARCHITECTURE.md'],
  ...readdirSync(join(repo, 'docs', 'plugins'))
    .filter((f) => f.endsWith('.md') && f !== 'README.md' && f !== 'ARCHITECTURE.md')
    .sort()
    .map((f) => [`docs/plugins/${f}`, `plugins/${f}`]),
  ...terminals.map((id) => [`terminals/${id}/README.md`, `terminals/${id}.md`]),
  ['CHANGELOG.md', 'changelog.md'],
  ['THIRD_PARTY.md', 'third-party.md'],
]

let copied = 0
let missing = 0
for (const [from, to] of files) {
  const src = join(repo, from)
  if (!existsSync(src)) {
    console.log(`sync-docs: ${from} is not in the repository, skipping`)
    missing += 1
    continue
  }
  const dest = join(content, to)
  mkdirSync(dirname(dest), { recursive: true })
  copyFileSync(src, dest)
  copied += 1
}

let images = 0
const screenshots = join(repo, 'docs', 'screenshots')
if (existsSync(screenshots)) {
  mkdirSync(shots, { recursive: true })
  for (const f of readdirSync(screenshots).filter((f) => f.endsWith('.png')).sort()) {
    copyFileSync(join(screenshots, f), join(shots, f))
    images += 1
  }
}

console.log(`sync-docs: ${copied} pages, ${images} screenshots${missing ? `, ${missing} missing` : ''}`)
