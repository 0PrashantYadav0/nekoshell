import { useEffect, useRef, useState } from 'react'
import { motion, useInView } from 'framer-motion'
import { Prompt } from './Prompt'
import { commands } from '../data/content'
import { useReducedMotion } from '../lib/motion'

type Line = { cls?: string; text: string }
type Step = { cmd: string; out: Line[] }

// Real output, shortened, from a Mac with the full profile.
const script: Step[] = [
  {
    cmd: 'nekoshell doctor',
    out: [
      { cls: 'ok', text: 'ok   homebrew            Homebrew 7.0.1' },
      { cls: 'ok', text: 'ok   zshrc               linked to ~/.nekoshell' },
      { cls: 'ok', text: 'ok   font glyphs         Nerd Fonts v3' },
      { cls: 'ok', text: 'ok   theme               mocha' },
      { cls: 'ok', text: 'ok   iterm2 prefs        default profile' },
      { cls: 'ok', text: 'ok   kitty panel         alt+m' },
      { cls: 'warn', text: 'warn ghostty hotkey      needs Accessibility' },
      { cls: 'ok', text: 'ok   art: pokemon        draws' },
      { cls: 'ok', text: 'ok   art: anime          draws' },
      { cls: 'ok', text: 'ok   greet time          92 ms' },
    ],
  },
  { cmd: 'nekoshell theme list', out: [{ text: 'frappe' }, { text: 'latte' }, { text: 'macchiato' }, { cls: 'k', text: 'mocha' }] },
  {
    cmd: 'nekoshell terminal list',
    out: [
      { text: 'ghostty        installed *' },
      { text: 'iterm2         installed *' },
      { text: 'kitty          installed *' },
      { text: 'terminal-app   installed *' },
      { text: 'warp           installed *' },
    ],
  },
  {
    cmd: 'nekoshell theme latte',
    out: [
      { cls: 'dim', text: 'theme: latte' },
      { cls: 'dim', text: 'iterm2: dynamic profile written' },
      { cls: 'dim', text: 'kitty: nekoshell.conf rendered' },
      { cls: 'dim', text: 'ghostty: config rendered' },
      { cls: 'dim', text: 'warp: settings.toml updated' },
      { cls: 'dim', text: 'terminal-app: profile installed' },
    ],
  },
]

export function Commands() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { margin: '-20% 0px' })
  const reduced = useReducedMotion()
  const [typed, setLines] = useState<Line[]>([])
  const [typing, setTyping] = useState('')
  const [finished, setDone] = useState(false)
  // With reduced motion the whole session is printed at once, nothing types.
  const lines = reduced ? script.flatMap((s) => [{ cls: 'cmd', text: s.cmd }, ...s.out]) : typed
  const done = reduced || finished

  useEffect(() => {
    if (reduced || !inView) return
    let cancelled = false
    const wait = (ms: number) => new Promise<void>((r) => setTimeout(r, ms))
    ;(async () => {
      while (!cancelled) {
        setLines([])
        for (const step of script) {
          for (let i = 1; i <= step.cmd.length; i++) {
            if (cancelled) return
            setTyping(step.cmd.slice(0, i))
            await wait(34 + Math.random() * 40)
          }
          await wait(280)
          setTyping('')
          setLines((l) => [...l, { cls: 'cmd', text: step.cmd }])
          for (const o of step.out) {
            if (cancelled) return
            setLines((l) => [...l, o])
            await wait(70)
          }
          await wait(1700)
        }
        setDone(true)
        await wait(2500)
        setDone(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [inView, reduced])

  const render = (l: Line, i: number) => {
    if (l.cls === 'cmd')
      return (
        <div key={i}>
          <span className="p">❯ </span>
          <span className="k">nekoshell</span>
          <span> {l.text.replace(/^nekoshell ?/, '')}</span>
        </div>
      )
    return <div key={i} className={l.cls}>{l.text}</div>
  }

  return (
    <section className="section" id="commands">
      <div className="wrap">
        <Prompt cmd="nekoshell help" out={<>one command, twelve subcommands, and the ones enabled plugins add</>} />
        <div className="cmds">
          <div className="tty" ref={ref} aria-label="A terminal running nekoshell doctor, theme list, terminal list and theme latte" role="img">
            <div className="tty__bar" aria-hidden="true">
              <i style={{ background: 'var(--red)' }} /><i style={{ background: 'var(--yellow)' }} /><i style={{ background: 'var(--green)' }} />
              <span>zsh — nekoshell</span>
            </div>
            <div className="tty__body" aria-hidden="true">
              {lines.map(render)}
              {!done && (
                <div>
                  <span className="p">❯ </span>
                  {typing.startsWith('nekoshell') ? <><span className="k">nekoshell</span>{typing.slice(9)}</> : typing}
                  <span className="prompt__cursor" />
                </div>
              )}
            </div>
          </div>
          <table className="cmdtable">
            <tbody>
              {commands.map((c) => {
                const [name, ...rest] = c.cmd.split(' ')
                return (
                  <tr key={c.cmd}>
                    <td><b>{name}</b> {rest.join(' ')}</td>
                    <td>{c.does}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        <motion.figure
          className="figure figure--scroll"
          style={{ margin: '2.5rem 0 0' }}
          initial={reduced ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-10% 0px' }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
        >
          <img src="/shots/doctor.png" alt="The whole output of nekoshell doctor on a Mac with the full profile: one row per check, every row ok except two warnings, Ghostty's hotkey and the shared Spotify client id" loading="lazy" width={1600} height={1599} />
        </motion.figure>
        <p className="figure__cap">The whole doctor on a Mac with the full profile and all five terminals, scrolled. Every row names a file or a version, and the two warnings say what to do.</p>
      </div>
    </section>
  )
}
