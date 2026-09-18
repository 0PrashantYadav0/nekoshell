import { motion } from 'framer-motion'
import { Prompt } from './Prompt'
import { useReducedMotion } from '../lib/motion'

const gets: { title: string; body: string; hue: string }[] = [
  { title: 'one zsh config', body: 'A zshrc that is a symlink into the checkout, antidote for the plugins, and a local.zsh that is yours and never overwritten.', hue: 'mauve' },
  { title: 'one prompt', body: 'Starship, in the flavour, with a git line. Or Powerlevel10k, or pure, one plugin add away.', hue: 'green' },
  { title: 'a greeting', body: 'A Pokémon, an anime still, a Minecraft block or an ANSI pattern next to the machine stats, in under 150 ms, on every new shell.', hue: 'peach' },
  { title: 'a music panel', body: 'Spotify in a drop-down terminal from ⌥M, or whatever player you enable, without leaving the keyboard.', hue: 'pink' },
  { title: 'five terminals, one look', body: 'JetBrainsMono Nerd Font and the same 26 colours in iTerm2, kitty, Ghostty, Warp and Terminal.app, applied by an adapter for each.', hue: 'blue' },
  { title: 'a doctor', body: 'One line per check, a fix named in every failing one, and an exit code CI can read. Nothing here is a mystery.', hue: 'yellow' },
]

export function WhatYouGet() {
  const reduced = useReducedMotion()
  return (
    <section className="section" id="get">
      <div className="wrap">
        <Prompt cmd="nekoshell install" args="--profile full" out={<>what the installer leaves behind, in six pieces</>} />
        <ul className="gets">
          {gets.map((g, i) => (
            <motion.li
              key={g.title}
              className="get"
              style={{ '--dot': `var(--${g.hue})` } as React.CSSProperties}
              initial={reduced ? false : { opacity: 0, x: -14 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-10% 0px' }}
              transition={{ duration: 0.55, delay: (i % 2) * 0.08 + Math.floor(i / 2) * 0.1, ease: [0.22, 1, 0.36, 1] }}
            >
              <span className="get__dot" aria-hidden="true" />
              <div>
                <h3>{g.title}</h3>
                <p>{g.body}</p>
              </div>
            </motion.li>
          ))}
        </ul>
      </div>
    </section>
  )
}
