import { useState } from 'react'
import { motion } from 'framer-motion'
import { Prompt } from './Prompt'
import { plugins, profiles, profileSet } from '../data/content'
import { useReducedMotion } from '../lib/motion'

const hue: Record<string, string> = { core: 'mauve', art: 'peach', tool: 'blue', prompt: 'green', ai: 'pink', window: 'yellow' }
const kinds: [string, string][] = [
  ['core', 'in every profile'],
  ['art', 'a picture for the greeting'],
  ['tool', 'a tool, themed'],
  ['prompt', 'another prompt'],
  ['ai', 'editors and AI tools'],
  ['window', 'the window manager'],
]

export function Plugins() {
  const [profile, setProfile] = useState('full')
  const on = profile === 'all' ? new Set(plugins.map((p) => p.name)) : profileSet(profile)
  const reduced = useReducedMotion()
  return (
    <section className="section" id="plugins">
      <div className="wrap">
        <Prompt cmd="nekoshell plugin" args="list" out={<>the core is the shell, the prompt, the theme and the five adapters; everything past that is one of 24 plugins, and a profile is a list of them</>} />
        <div className="profiles" role="group" aria-label="Profiles">
          {profiles.map((p) => (
            <button key={p.name} aria-pressed={profile === p.name} onClick={() => setProfile(p.name)}>--profile {p.name}</button>
          ))}
          <button aria-pressed={profile === 'all'} onClick={() => setProfile('all')}>every plugin</button>
          <span className="profiles__note">{profile === 'all' ? 'the whole shelf, each one plugin add away' : profiles.find((p) => p.name === profile)?.note}</span>
        </div>
        <ul className="chips">
          {plugins.map((p, i) => (
            <motion.li
              key={p.name}
              className="chip"
              data-on={on.has(p.name)}
              tabIndex={0}
              style={{ '--hue': `var(--${hue[p.kind]})` } as React.CSSProperties}
              initial={reduced ? false : { opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-5% 0px' }}
              transition={{ duration: 0.4, delay: i * 0.025 }}
            >
              {p.name}
              <span className="chip__tip" role="tooltip">{p.summary}</span>
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
