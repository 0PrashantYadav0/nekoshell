import { useEffect, useRef, useState } from 'react'
import { motion, useMotionValueEvent, useScroll } from 'framer-motion'
import { Prompt } from './Prompt'
import { shots } from '../data/content'

// The greeting, three ways. The frame is pinned while the section scrolls
// past, and the picture changes with the scroll position; the tabs jump to
// the matching spot. Under 880px the pin is off and the tabs do the work.
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
          <div>
            <Prompt cmd="nekoshell greet" args={`--art ${shots[active].art}`} out={<>a new picture on every shell you open, beside the machine stats and the palette</>} />
          </div>
          <div className="shots__frame">
            {shots.map((s, i) => (
              <motion.img
                key={s.art}
                src={s.file}
                alt={`An iTerm2 window after nekoshell greet --art ${s.art}`}
                loading={i === 0 ? 'eager' : 'lazy'}
                initial={false}
                animate={{ opacity: i === active ? 1 : 0, scale: i === active ? 1 : 1.03 }}
                transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
              />
            ))}
          </div>
          <div className="shots__tabs" role="tablist" aria-label="Art providers">
            {shots.map((s, i) => (
              <button key={s.art} role="tab" className="shots__tab" aria-current={i === active} aria-selected={i === active} onClick={() => jump(i)}>
                {s.art}
              </button>
            ))}
          </div>
          <p className="shots__cap">{shots[active].caption}</p>
        </div>
      </div>
    </section>
  )
}
