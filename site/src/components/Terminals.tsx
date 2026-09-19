import { lazy, useRef, useState } from 'react'
import { useScroll, useTransform } from 'framer-motion'
import { SectionHead } from './SectionHead'
import { LazyCanvas } from './LazyCanvas'

const TerminalsScene = lazy(() => import('./TerminalsScene'))
import { terminals } from '../data/content'
import { useReducedMotion } from '../lib/motion'

export function Terminals() {
  const ref = useRef<HTMLElement>(null)
  const reduced = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 80%', 'center center'] })
  const progress = useTransform(scrollYProgress, [0, 1], [reduced ? 1 : 0, 1])
  const [hovered, setHovered] = useState<string | null>(null)

  return (
    <section className="section" id="terminals" ref={ref}>
      <div className="wrap">
        <SectionHead cmd="nekoshell terminal use all" title="Five terminals, the same look" sub="An adapter for each terminal applies the font, the 26 colours and a music panel where the terminal has one. Configure one, a few, or all of them at once." />
        <div className="terms">
          <div className="terms__scene" role="img" aria-label="Five terminal windows, one per adapter, fanned out in 3D">
            <LazyCanvas
              camera={{ position: [0, 0.3, 7.6], fov: 34 }}
              fallback={
                <ul className="scene-still scene-names">
                  {terminals.map((t) => (
                    <li key={t.id} style={{ '--hue': `var(--${t.hue})` } as React.CSSProperties}>{t.name}</li>
                  ))}
                </ul>
              }
            >
              <TerminalsScene progress={progress} hovered={hovered} />
            </LazyCanvas>
          </div>
          <ul className="card terms__list">
            {terminals.map((t) => (
              <li
                key={t.id}
                className="term"
                style={{ '--hue': `var(--${t.hue})` } as React.CSSProperties}
                onPointerEnter={() => setHovered(t.id)}
                onPointerLeave={() => setHovered(null)}
                onFocus={() => setHovered(t.id)}
                onBlur={() => setHovered(null)}
                tabIndex={0}
              >
                <h3>{t.name}</h3>
                <dl>
                  <dt>inline images</dt><dd>{t.images}</dd>
                  <dt>background</dt><dd>{t.background}</dd>
                  <dt>panel</dt><dd>{t.panel}</dd>
                </dl>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}
