import { useEffect, useRef, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { repo } from '../data/content'
import { useFlavour } from '../lib/flavour'

// The section links carry the front page in front of the fragment, so they
// work from a docs page as well as from the top of the landing page.
const links = [
  ['/#greet', 'Greeting'],
  ['/#terminals', 'Terminals'],
  ['/#commands', 'Commands'],
  ['/#plugins', 'Plugins'],
  ['/#themes', 'Themes'],
]

export function Nav() {
  const [scrolled, setScrolled] = useState(false)
  const [open, setOpen] = useState(false)
  const menuButton = useRef<HTMLButtonElement>(null)
  const { flavour, setFlavour } = useFlavour()
  const { pathname } = useLocation()
  const onDocs = pathname === '/docs' || pathname.startsWith('/docs/')
  const light = flavour === 'latte'
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 8)
    on()
    window.addEventListener('scroll', on, { passive: true })
    return () => window.removeEventListener('scroll', on)
  }, [])
  // Escape closes the panel and hands the focus back to the button that
  // opened it, so the keyboard never lands in a panel that is not there.
  useEffect(() => {
    if (!open) return
    const on = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      setOpen(false)
      menuButton.current?.focus()
    }
    window.addEventListener('keydown', on)
    return () => window.removeEventListener('keydown', on)
  }, [open])
  const docsLink = (
    <Link to="/docs" aria-current={onDocs ? 'page' : undefined} onClick={() => setOpen(false)}>Docs</Link>
  )
  return (
    <header className="nav" data-scrolled={scrolled}>
      <div className="wrap nav__in">
        <Link className="wordmark" to="/">
          <img src="/neko.png" alt="" width={28} height={28} />
          nekoshell
        </Link>
        <nav className="nav__links" aria-label="Sections">
          {links.map(([href, label]) => (
            <a key={href} href={href}>{label}</a>
          ))}
          {docsLink}
          <a href="/#author">Author</a>
        </nav>
        <div className="nav__cta">
          <button
            type="button"
            className="btn nav__menu"
            ref={menuButton}
            aria-expanded={open}
            aria-controls="nav-menu"
            onClick={() => setOpen((v) => !v)}
          >
            Menu
          </button>
          <a className="btn nav__gh" href={repo} target="_blank" rel="noreferrer">
            <GitHubIcon /> GitHub
          </a>
          <a className="btn btn--fill" href="/#install">Install</a>
          <button className="btn btn--icon" onClick={() => setFlavour(light ? 'mocha' : 'latte')} aria-label={light ? 'Switch to the dark flavour' : 'Switch to the light flavour'} title={light ? 'mocha' : 'latte'}>
            {light ? (
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></svg>
            ) : (
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z" /></svg>
            )}
          </button>
        </div>
      </div>
      {/* The panel is in the page whether it is open or not, so the button's
          aria-controls always names something real. */}
      <nav className="nav__panel" id="nav-menu" aria-label="Menu" hidden={!open}>
        <div className="wrap">
          {links.map(([href, label]) => (
            <a key={href} href={href} onClick={() => setOpen(false)}>{label}</a>
          ))}
          {docsLink}
          <a href="/#author" onClick={() => setOpen(false)}>Author</a>
          <a href={repo} target="_blank" rel="noreferrer" onClick={() => setOpen(false)}>GitHub</a>
        </div>
      </nav>
    </header>
  )
}

export function GitHubIcon() {
  return (
    <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
    </svg>
  )
}
