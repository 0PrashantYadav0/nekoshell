# nekoshell landing page

The single-page site for nekoshell: a Vite and React app under `site/`, deployed on Vercel. It renders facts from the repository (`src/data/content.ts` mirrors the plugin summaries, the command table and the terminal capabilities; `src/data/palettes.json` is a copy of `core/theme/palettes.json`) and three 3D scenes: the neko mascot from `docs/assets/neko.stl`, five terminal windows, and the palette of the flavour in force.

## Running it

```bash
cd site
npm install
npm run dev      # http://localhost:5173
npm run build    # dist/
npm run lint
```

## Deploying on Vercel

Import the repository, set **Root Directory** to `site`, and keep the defaults: framework Vite, build `npm run build`, output `dist`. `.npmrc` sets `legacy-peer-deps`, which `@react-three/fiber`'s optional Expo peers need under npm.

## Keeping it true

When a plugin, a command or a terminal changes, change `src/data/content.ts` to match; when a palette changes, copy `core/theme/palettes.json` over `src/data/palettes.json`. The screenshots in `public/shots/` are copies of `docs/screenshots/`.
