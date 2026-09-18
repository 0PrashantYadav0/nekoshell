import { lazy } from 'react'
import { SectionHead } from './SectionHead'
import { LazyCanvas } from './LazyCanvas'

const PaletteScene = lazy(() => import('./PaletteScene'))
import { flavours, paletteOf, useFlavour, type Flavour } from '../lib/flavour'

const about: Record<Flavour, string> = {
  mocha: 'the darkest, and the default',
  macchiato: 'a little lighter, the same accents',
  frappe: 'soft, blue-grey',
  latte: 'the light one, for daylight',
}
const swatch = ['mauve', 'pink', 'red', 'peach', 'yellow', 'green', 'blue']

export function Themes() {
  const { flavour, setFlavour } = useFlavour()
  return (
    <section className="section" id="themes">
      <div className="wrap">
        <SectionHead cmd={`nekoshell theme ${flavour}`} title="Four flavours, one switch" sub={<>A theme switch re-renders every terminal, the prompt, bat, btop, lazygit, yazi and the rest. <b>theme auto</b> follows the Mac's appearance.</>} />
        <div className="themes">
          <div className="themes__scene" role="img" aria-label={`The 26 colours of Catppuccin ${flavour} as spheres around a prompt block`}>
            <LazyCanvas camera={{ position: [0, 2.8, 8.4], fov: 34 }}>
              <PaletteScene />
            </LazyCanvas>
          </div>
          <div>
            <p style={{ color: 'var(--subtext1)', marginBottom: '1rem' }}>Pick one. The page changes with it, the way every terminal on the Mac does.</p>
            <div className="flavours" role="group" aria-label="Flavours">
              {flavours.map((f) => {
                const p = paletteOf(f)
                return (
                  <button key={f} className="flavour" aria-pressed={flavour === f} onClick={() => setFlavour(f)}>
                    <span className="flavour__sw" aria-hidden="true">
                      {swatch.map((k) => <i key={k} style={{ background: `#${p[k]}` }} />)}
                    </span>
                    <span>
                      <b>{f}</b>
                      <small>{about[f]}</small>
                    </span>
                    <code>base #{p.base}</code>
                  </button>
                )
              })}
            </div>
            <p className="themes__note">Every colour on the page and in the rig comes from one file, core/theme/palettes.json. Nothing is hard-coded twice.</p>
          </div>
        </div>
        <figure className="figure" style={{ margin: '2.5rem 0 0' }}>
          <img
            src={flavour === 'latte' ? '/shots/greet-pokemon-latte.png' : '/shots/greet-pokemon.png'}
            alt={`The greeting with a Pok\u00e9mon sprite in ${flavour === 'latte' ? 'latte' : 'mocha'}`}
            loading="lazy"
            width={1600}
            height={flavour === 'latte' ? 531 : 576}
          />
        </figure>
        <p className="figure__cap">{flavour === 'latte' ? 'The same greeting after nekoshell theme latte: the light base, the darker accents, the swatch in the new colours.' : 'The greeting in mocha. Pick latte above to see the same window after nekoshell theme latte.'}</p>
      </div>
    </section>
  )
}
