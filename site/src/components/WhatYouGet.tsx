import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { SectionHead } from './SectionHead'
import { useReducedMotion } from '../lib/motion'

// Three rows as the doctor printed them in docs/screenshots/doctor.png.
const doctorRows = ['ok   theme               mocha', 'ok   bat theme           Catppuccin Mocha', 'ok   greet time          133 ms'].join('\n')

const gets: { title: string; body: string; hue: string; icon: React.ReactNode; extra?: React.ReactNode }[] = [
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
    icon: <path d="M20 6L9 17l-5-5" />,
    extra: (
      <>
        <pre className="get__rows" tabIndex={0} role="group" aria-label="Three rows of nekoshell doctor output, as the screenshot lower down shows them">{doctorRows}</pre>
        <Link className="get__more" to="/docs/install">The check step, in the docs</Link>
      </>
    ) },
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
              transition={{ type: 'spring', bounce: 0, duration: 0.55, delay: (i % 3) * 0.06 }}
            >
              <span className="get__icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{g.icon}</svg>
              </span>
              <h3>{g.title}</h3>
              <p>{g.body}</p>
              {g.extra}
            </motion.li>
          ))}
        </ul>
      </div>
    </section>
  )
}
