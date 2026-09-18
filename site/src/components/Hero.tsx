import { lazy, useRef } from 'react'
import { useScroll, useTransform, motion } from 'framer-motion'
import { LazyCanvas } from './LazyCanvas'
import { GitHubIcon } from './Nav'
import { useCopy, useReducedMotion } from '../lib/motion'
import { repo } from '../data/content'

const NekoScene = lazy(() => import('./NekoScene'))

const line = 'brew tap 0PrashantYadav0/nekoshell && brew install nekoshell && nekoshell install'

export function Hero() {
  const ref = useRef<HTMLElement>(null)
  const reduced = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const spin = useTransform(scrollYProgress, [0, 1], [0, reduced ? 0 : Math.PI * 2])
  const fade = useTransform(scrollYProgress, [0, 0.7], [1, reduced ? 1 : 0])
  const rise = useTransform(scrollYProgress, [0, 0.7], [0, reduced ? 0 : -40])
  const [done, copy] = useCopy()

  const reveal = (i: number) =>
    reduced ? {} : { initial: { opacity: 0, y: 14 }, animate: { opacity: 1, y: 0 }, transition: { duration: 0.6, delay: 0.1 + i * 0.1, ease: [0.22, 1, 0.36, 1] as const } }

  return (
    <section className="hero" id="top" ref={ref}>
      <div className="wrap hero__grid">
        <motion.div style={{ opacity: fade, y: rise }}>
          <motion.div className="hero__meta" {...reveal(0)}>
            <span>Release 0.2.0</span>
            <span>MIT licence</span>
            <span>macOS</span>
          </motion.div>
          <motion.h1 className="hero__title" {...reveal(1)}>
            A themed terminal for your Mac, in one command.
          </motion.h1>
          <motion.p className="hero__lead" {...reveal(2)}>
            nekoshell sets up zsh, a prompt, a greeting with a picture, and a music panel, and gives iTerm2, kitty, Ghostty, Warp and Terminal.app the same font and Catppuccin colours. One command installs it, themes it and checks it.
          </motion.p>
          <motion.div className="hero__cta" {...reveal(3)}>
            <a className="btn btn--fill btn--lg" href="#install">Install with Homebrew</a>
            <a className="btn btn--lg" href={repo} target="_blank" rel="noreferrer"><GitHubIcon /> View on GitHub</a>
          </motion.div>
          <motion.div className="hero__line" {...reveal(4)}>
            <code>{line}</code>
            <button className="copy" data-done={done} onClick={() => copy(line)} aria-live="polite">{done ? 'Copied' : 'Copy'}</button>
          </motion.div>
        </motion.div>
        <div className="hero__scene" aria-label="The neko mascot, a black chibi cat sitting on a mauve prompt block, as a 3D model you can turn" role="img">
          <div className="hero__ground" />
          <LazyCanvas camera={{ position: [0.8, 0.9, 11.2], fov: 28 }} shadows>
            <NekoScene spin={spin} />
          </LazyCanvas>
          <span className="hero__hint" aria-hidden="true">Drag to turn</span>
        </div>
      </div>
    </section>
  )
}
