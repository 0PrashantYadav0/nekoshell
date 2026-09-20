# nekoshell landing page

The site for nekoshell: a Vite and React app under `site/`, deployed on Vercel. The front page at `/` renders facts from the repository (`src/data/content.ts` mirrors the plugin summaries, the command table and the terminal capabilities; `src/data/palettes.json` is a copy of `core/theme/palettes.json`) and three 3D scenes: the neko mascot from `docs/assets/neko.stl`, five terminal windows, and the palette of the flavour in force. `/docs` renders the repository's own documentation.

## Running it

```bash
cd site
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
npm run lint
npm test         # the unit tests in src/lib
npm run preview  # serves dist/, deep links included
```

## The documentation at /docs

`/docs` and everything under it render the pages a user reads — `docs/*.md`, `docs/plugins/*.md`, the five `terminals/<id>/README.md`, `CHANGELOG.md` and `THIRD_PARTY.md` — in the front page's look, with a sidebar, an on-page table of contents and copyable code blocks. Slugs follow the file names: `docs/INSTALL.md` is `/docs/install`, `docs/plugins/tmux.md` is `/docs/plugins/tmux`, `terminals/kitty/README.md` is `/docs/terminals/kitty`.

Nothing under `src/` may read outside `site/` at build time, because Vercel builds with Root Directory `site` and the rest of the repository is not on disk there. So the Markdown lives under `src/content/docs/` as **committed copies**, and `scripts/sync-docs.mjs` refreshes them:

```bash
npm run sync-docs
```

`prebuild` runs the same script, so `npm run build` in a checkout picks up any documentation change by itself; on Vercel the script finds no repository above `site/`, prints one line and exits 0, leaving the committed copies in place. It also copies `docs/screenshots/*.png` into `public/shots/`. Commit what it changes along with the change to the documentation.

Which pages ship is decided by AGENTS.md, section "Docs". A contributor-only page (`docs/contributing/`, `docs/ci-checks/`, `docs/ai/`, `AGENTS.md`) is not copied, and a link to one is rendered as a link to GitHub.

## Deploying on Vercel

Import the repository, set **Root Directory** to `site`, and keep the defaults: framework Vite, build `npm run build`, output `dist`. `.npmrc` sets `legacy-peer-deps`, which `@react-three/fiber`'s optional Expo peers need under npm.

The site is a single-page app with a real router, so a reload on `/docs/plugins/tmux` has to reach `index.html`. `vercel.json` rewrites every path to it:

```json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```

Vercel serves an existing file first, so `/assets/*`, `/shots/*`, `/models/*` and `/neko.png` are unaffected. `npm run dev` and `npm run preview` both fall back to `index.html` the same way, which is how a deep link is checked locally.

## Keeping it true

When a plugin, a command or a terminal changes, change `src/data/content.ts` to match; when a palette changes, copy `core/theme/palettes.json` over `src/data/palettes.json`. When a documentation page changes, run `npm run sync-docs`. Colours come from the palette variables on `:root` and never from a hex literal in a component or a stylesheet.
