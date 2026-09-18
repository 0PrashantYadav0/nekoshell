import { lazy, useRef } from 'react'
import { useScroll, useTransform, motion } from 'framer-motion'
import { LazyCanvas } from './LazyCanvas'

const NekoScene = lazy(() => import('./NekoScene'))
import { useCopy, useReducedMotion } from '../lib/motion'
import { repo, tap } from '../data/content'

const line = 'brew tap 0PrashantYadav0/nekoshell && brew install nekoshell && nekoshell install'

const badges: [string, string, string][] = [
  [`${repo}/releases/latest`, 'https://img.shields.io/github/v/release/0PrashantYadav0/nekoshell?style=flat-square&labelColor=1e1e2e&color=cba6f7&label=release', 'latest release'],
  [`${repo}/actions/workflows/ci.yml`, 'https://img.shields.io/github/actions/workflow/status/0PrashantYadav0/nekoshell/ci.yml?branch=main&style=flat-square&labelColor=1e1e2e&color=a6e3a1&label=ci', 'ci'],
  [`${repo}/stargazers`, 'https://img.shields.io/github/stars/0PrashantYadav0/nekoshell?style=flat-square&labelColor=1e1e2e&color=f9e2af&label=stars', 'stars'],
  [`${repo}/releases`, 'https://img.shields.io/github/downloads/0PrashantYadav0/nekoshell/total?style=flat-square&labelColor=1e1e2e&color=89b4fa&label=downloads', 'downloads'],
  [tap, 'https://img.shields.io/badge/homebrew-0PrashantYadav0%2Fnekoshell-f38ba8?style=flat-square&labelColor=1e1e2e', 'homebrew tap'],
  [`${repo}/blob/main/LICENSE`, 'https://img.shields.io/github/license/0PrashantYadav0/nekoshell?style=flat-square&labelColor=1e1e2e&color=f5c2e7&label=license', 'license'],
]

export function Hero() {
  const ref = useRef<HTMLElement>(null)
  const reduced = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const spin = useTransform(scrollYProgress, [0, 1], [0, reduced ? 0 : Math.PI * 2])
  const fade = useTransform(scrollYProgress, [0, 0.7], [1, reduced ? 1 : 0])
  const rise = useTransform(scrollYProgress, [0, 0.7], [0, reduced ? 0 : -60])
  const [done, copy] = useCopy()

  const stagger = reduced ? {} : { initial: { opacity: 0, y: 18 }, animate: { opacity: 1, y: 0 } }
  const delay = (i: number) => (reduced ? {} : { transition: { duration: 0.7, delay: 0.15 + i * 0.12, ease: [0.22, 1, 0.36, 1] as const } })

  return (
    <section className="hero" id="top" ref={ref}>
      <div className="wrap hero__grid">
        <motion.div className="hero__copy" style={{ opacity: fade, y: rise }}>
          <motion.h1 className="hero__title" {...stagger} {...delay(0)}>
            <span>the terminal,</span>
            <span>with a cat</span>
            <span className="t-neko">in it.</span>
          </motion.h1>
          <motion.p className="lead hero__lead" {...stagger} {...delay(1)}>
            nekoshell is a Catppuccin terminal rig for macOS: one zsh config, one prompt, a greeting with a Pokémon or an anime still, a music panel, and the same font and colours in iTerm2, kitty, Ghostty, Warp and Terminal.app. One command installs it, themes it and checks it.
          </motion.p>
          <motion.div className="hero__line" {...stagger} {...delay(2)}>
            <code>{line}</code>
            <button className="copy" data-done={done} onClick={() => copy(line)} aria-live="polite">{done ? 'copied' : 'copy'}</button>
          </motion.div>
          <motion.div className="badges" {...stagger} {...delay(3)}>
            {badges.map(([href, src, alt]) => (
              <a key={alt} href={href} target="_blank" rel="noreferrer"><img src={src} alt={alt} height={20} /></a>
            ))}
          </motion.div>
        </motion.div>
        <div className="hero__scene" aria-label="The neko mascot, a black chibi cat sitting on a mauve prompt block, as a 3D model you can turn" role="img">
          <div className="hero__ground" />
          <LazyCanvas camera={{ position: [0.8, 0.9, 11.2], fov: 28 }} shadows>
            <NekoScene spin={spin} />
          </LazyCanvas>
          <span className="hero__hint" aria-hidden="true">drag to turn, scroll to spin</span>
        </div>
      </div>
    </section>
  )
}
