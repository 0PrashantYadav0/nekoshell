import { useEffect, useRef, useState } from 'react'
import { motion } from 'framer-motion'
import { SectionHead } from './SectionHead'
import { plugins, profiles, profileSet } from '../data/content'
import { useReducedMotion } from '../lib/motion'

const hue: Record<string, string> = { core: 'mauve', art: 'peach', tool: 'blue', prompt: 'green', ai: 'pink', window: 'yellow' }
const kinds: [string, string][] = [
  ['core', 'In every profile'],
  ['art', 'Art for the greeting'],
  ['tool', 'A tool, themed'],
  ['prompt', 'Another prompt'],
  ['ai', 'Editors and AI tools'],
  ['window', 'Window manager'],
]

export function Plugins() {
  const [profile, setProfile] = useState('full')
  const [open, setOpen] = useState<string | null>(null)
  const list = useRef<HTMLUListElement>(null)
  const on = profile === 'all' ? new Set(plugins.map((p) => p.name)) : profileSet(profile)
  const reduced = useReducedMotion()

  // A summary hangs from its chip's left edge. For the chips at the end of a
  // row that would hang it past the page, so those hang from the right edge
  // instead and the page keeps its width.
  useEffect(() => {
    const ul = list.current
    if (!ul) return
    const place = () => {
      for (const item of Array.from(ul.children) as HTMLElement[]) {
        const tip = item.querySelector<HTMLElement>('.chip__tip')
        if (!tip) continue
        item.dataset.tipEnd = String(item.offsetLeft + tip.offsetWidth > ul.clientWidth)
      }
    }
    place()
    const ro = new ResizeObserver(place)
    ro.observe(ul)
    return () => ro.disconnect()
  }, [])

  return (
    <section className="section" id="plugins">
      <div className="wrap">
        <SectionHead cmd="nekoshell plugin list" title="Twenty-four plugins, three profiles" sub="The core is the shell, the prompt, the theme and the five adapters. Everything else is a plugin, and a profile is a list of them." />
        <div className="profiles">
          <div className="seg" role="group" aria-label="Profiles">
            {profiles.map((p) => (
              <button key={p.name} aria-pressed={profile === p.name} onClick={() => setProfile(p.name)}>{p.name}</button>
            ))}
            <button aria-pressed={profile === 'all'} onClick={() => setProfile('all')}>All plugins</button>
          </div>
          <span className="profiles__note">
            <b>{on.size} of {plugins.length} plugins</b>
            {' — '}
            {profile === 'all' ? 'the whole shelf, each one plugin add away' : profiles.find((p) => p.name === profile)?.note}
          </span>
        </div>
        <ul className="chips" ref={list}>
          {plugins.map((p, i) => (
            <motion.li
              key={p.name}
              className="chips__item"
              data-open={open === p.name}
              initial={reduced ? false : { opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-5% 0px' }}
              transition={{ type: 'spring', bounce: 0, duration: 0.45, delay: i * 0.02 }}
            >
              <button
                type="button"
                className="chip"
                data-on={on.has(p.name)}
                aria-expanded={open === p.name}
                aria-controls={`plugin-${p.name}`}
                style={{ '--hue': `var(--${hue[p.kind]})` } as React.CSSProperties}
                onClick={() => setOpen((cur) => (cur === p.name ? null : p.name))}
              >
                {p.name}
              </button>
              <span className="chip__tip" id={`plugin-${p.name}`}>{p.summary}</span>
            </motion.li>
          ))}
        </ul>
        <div className="chips__legend" aria-label="Kinds">
          {kinds.map(([k, label]) => (
            <span key={k} style={{ '--hue': `var(--${hue[k]})` } as React.CSSProperties}><i aria-hidden="true" />{label}</span>
          ))}
        </div>
      </div>
    </section>
  )
}
