import { useEffect, useRef, useState } from 'react'
import { motion, useMotionValueEvent, useScroll } from 'framer-motion'
import { SectionHead } from './SectionHead'
import { shots } from '../data/content'

// The greeting, four ways. The frame is pinned while the section scrolls
// past, and the picture changes with the scroll position; the segments jump
// to the matching spot. Under 880px the pin is off and the segments do it.
export function Shots() {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end end'] })
  const [active, setActive] = useState(0)
  const [pinned, setPinned] = useState(true)

  useEffect(() => {
    const m = window.matchMedia('(max-width: 880px)')
    const on = () => setPinned(!m.matches)
    on()
    m.addEventListener('change', on)
    return () => m.removeEventListener('change', on)
  }, [])

  useMotionValueEvent(scrollYProgress, 'change', (v) => {
    if (!pinned) return
    setActive(Math.min(shots.length - 1, Math.max(0, Math.floor(v * shots.length * 0.999))))
  })

  const jump = (i: number) => {
    if (!pinned || !ref.current) return setActive(i)
    const top = ref.current.offsetTop
    const span = ref.current.offsetHeight - window.innerHeight
    window.scrollTo({ top: top + (span * (i + 0.5)) / shots.length, behavior: 'smooth' })
  }

  return (
    <section className="section" id="greet">
      <div className="shots" ref={ref}>
        <div className="wrap shots__pin">
          <SectionHead cmd={`nekoshell greet --art ${shots[active].art}`} title="A picture on every new shell" sub="The greeting draws beside the machine stats and the palette, from whichever art providers you enable." />
          <div className="shots__frame">
            {shots.map((s, i) => (
              <motion.img
                key={s.art}
                src={s.file}
                alt={`An iTerm2 window after nekoshell greet --art ${s.art}`}
                loading={i === 0 ? 'eager' : 'lazy'}
                initial={false}
                animate={{ opacity: i === active ? 1 : 0, scale: i === active ? 1 : 1.02 }}
                transition={{ type: 'spring', bounce: 0, duration: 0.55 }}
              />
            ))}
          </div>
          <div className="shots__row">
            <div className="seg" role="tablist" aria-label="Art providers">
              {shots.map((s, i) => (
                <button key={s.art} role="tab" aria-selected={i === active} onClick={() => jump(i)}>{s.art}</button>
              ))}
            </div>
            <p className="shots__cap">{shots[active].caption}</p>
          </div>
        </div>
      </div>
    </section>
  )
}
