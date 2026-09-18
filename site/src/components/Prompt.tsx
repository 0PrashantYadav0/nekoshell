import { useEffect, useState } from 'react'
import { useInView } from 'framer-motion'
import { useRef } from 'react'
import { useReducedMotion } from '../lib/motion'

// A section heading written as the prompt line that produces the section:
// the chevron, the command, its arguments. It types itself in the first time
// it scrolls into view, then keeps a blinking cursor.
export function Prompt({ cmd, args, id, out }: { cmd: string; args?: string; id?: string; out?: React.ReactNode }) {
  const ref = useRef<HTMLHeadingElement>(null)
  const inView = useInView(ref, { once: true, margin: '-10% 0px' })
  const reduced = useReducedMotion()
  const full = args ? `${cmd} ${args}` : cmd
  const [n, setN] = useState(reduced ? full.length : 0)

  useEffect(() => {
    if (!inView || reduced) return
    let i = 0
    const t = window.setInterval(() => {
      i += 1
      setN(i)
      if (i >= full.length) window.clearInterval(t)
    }, 38)
    return () => window.clearInterval(t)
  }, [inView, reduced, full.length])

  const typed = full.slice(0, n)
  const cmdPart = typed.slice(0, cmd.length)
  const argPart = typed.slice(cmd.length)
  return (
    <>
      <h2 className="prompt" id={id} ref={ref} aria-label={full}>
        <span className="prompt__chev" aria-hidden="true">❯</span>
        <span aria-hidden="true">
          <span className="prompt__cmd">{cmdPart}</span>
          <span className="prompt__arg">{argPart}</span>
          <span className="prompt__cursor" />
        </span>
      </h2>
      {out && <div className="prompt__out">{out}</div>}
    </>
  )
}
