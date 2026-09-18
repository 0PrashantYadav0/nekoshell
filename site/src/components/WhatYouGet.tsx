import { motion } from 'framer-motion'
import { SectionHead } from './SectionHead'
import { useReducedMotion } from '../lib/motion'

const gets: { title: string; body: string; hue: string; icon: React.ReactNode }[] = [
  { title: 'One zsh config', hue: 'mauve', body: 'A zshrc linked from the checkout, antidote for plugins, and a local.zsh that is yours and never overwritten.',
    icon: <path d="M4 17l6-5-6-5M12 19h8" /> },
  { title: 'One prompt', hue: 'green', body: 'Starship in the flavour, with a git line. Powerlevel10k or pure are one plugin add away.',
    icon: <path d="M5 12h14M13 6l6 6-6 6" /> },
  { title: 'A greeting', hue: 'peach', body: 'A Pokémon, an anime still, a Minecraft block or an ANSI pattern beside the machine stats, in under 150 ms.',
    icon: <><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M3 15l5-5 4 4 3-3 6 6" /></> },
  { title: 'A music panel', hue: 'pink', body: 'Spotify in a drop-down terminal from ⌥M, or whichever player you enable, without leaving the keyboard.',
    icon: <path d="M9 18V6l11-2v12M9 18a3 3 0 11-6 0 3 3 0 016 0zM20 16a3 3 0 11-6 0 3 3 0 016 0z" /> },
  { title: 'Five terminals, one look', hue: 'blue', body: 'JetBrainsMono Nerd Font and the same 26 colours in iTerm2, kitty, Ghostty, Warp and Terminal.app.',
    icon: <><rect x="3" y="3" width="8" height="8" rx="1.5" /><rect x="13" y="3" width="8" height="8" rx="1.5" /><rect x="3" y="13" width="8" height="8" rx="1.5" /><rect x="13" y="13" width="8" height="8" rx="1.5" /></> },
  { title: 'A doctor', hue: 'yellow', body: 'One line per check, a fix named in every failing one, and an exit code CI can read.',
    icon: <path d="M20 6L9 17l-5-5" /> },
]

export function WhatYouGet() {
  const reduced = useReducedMotion()
  return (
    <section className="section" id="get">
      <div className="wrap">
        <SectionHead cmd="nekoshell install" title="Everything the installer sets up" sub="Six pieces, configured together, backed up before anything is replaced." />
        <ul className="gets">
          {gets.map((g, i) => (
            <motion.li
              key={g.title}
              className="card get"
              style={{ '--hue': `var(--${g.hue})` } as React.CSSProperties}
              initial={reduced ? false : { opacity: 0, y: 14 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-8% 0px' }}
              transition={{ duration: 0.5, delay: (i % 3) * 0.07, ease: [0.22, 1, 0.36, 1] }}
            >
              <span className="get__icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{g.icon}</svg>
              </span>
              <h3>{g.title}</h3>
              <p>{g.body}</p>
            </motion.li>
          ))}
        </ul>
      </div>
    </section>
  )
}
