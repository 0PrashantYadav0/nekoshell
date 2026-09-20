import { useState } from 'react'
import { SectionHead } from './SectionHead'
import { Lightbox } from './Lightbox'
import { shots } from '../data/content'

// The greeting, four ways, all on one screen: a grid of window frames, the
// command that drew each one in its title bar and its caption under it. A
// click opens the picture larger in the lightbox.
export function Shots() {
  const [open, setOpen] = useState<{ index: number; origin: HTMLElement } | null>(null)

  return (
    <section className="section" id="greet">
      <div className="wrap">
        <SectionHead cmd="nekoshell greet" title="A picture on every new shell" sub="The greeting draws beside the machine stats and the palette, from whichever art providers you enable." />
        <ul className="gallery">
          {shots.map((s, i) => (
            <li key={s.art} className="shot">
              <button type="button" className="shot__open" onClick={(e) => setOpen({ index: i, origin: e.currentTarget })} aria-label={`Open the ${s.art} greeting larger`}>
                <span className="shot__bar" aria-hidden="true">
                  <i /><i /><i />
                  <code>nekoshell greet --art {s.art}</code>
                </span>
                <img src={s.file} alt={`An iTerm2 window after nekoshell greet --art ${s.art}`} loading="lazy" width={1600} height={s.height} />
              </button>
              <p className="shot__cap">{s.caption}</p>
            </li>
          ))}
        </ul>
        <Lightbox
          items={shots}
          index={open?.index ?? null}
          origin={open?.origin ?? null}
          onIndex={(index) => open && setOpen({ ...open, index })}
          onClose={() => setOpen(null)}
        />
      </div>
    </section>
  )
}
