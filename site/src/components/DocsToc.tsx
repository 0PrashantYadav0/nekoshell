import { useEffect, useState } from 'react'
import type { Heading } from '../lib/docs'

/** The heading the reader is at: the first one showing under the nav, or the
 *  last one passed when the window sits between two. The page keys this
 *  component, so the state starts empty again on every page. */
function useActiveHeading(headings: Heading[]): string {
  const [active, setActive] = useState('')
  useEffect(() => {
    const nodes = headings.map((h) => document.getElementById(h.id)).filter((n): n is HTMLElement => !!n)
    if (nodes.length === 0) return
    const seen = new Set<string>()
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) seen.add(entry.target.id)
          else seen.delete(entry.target.id)
        }
        const first = nodes.find((n) => seen.has(n.id))
        if (first) setActive(first.id)
        else {
          const passed = nodes.filter((n) => n.getBoundingClientRect().top < 100).pop()
          if (passed) setActive(passed.id)
        }
      },
      // The nav is 56 px tall; below it is the band that counts as "here".
      { rootMargin: '-72px 0px -70% 0px' },
    )
    for (const node of nodes) io.observe(node)
    return () => io.disconnect()
  }, [headings])
  return active
}

export function DocsToc({ headings }: { headings: Heading[] }) {
  const active = useActiveHeading(headings)
  if (headings.length === 0) return null
  return (
    <nav className="docs__toc" aria-label="On this page">
      <p className="docs__toc-head">On this page</p>
      <TocList headings={headings} active={active} />
    </nav>
  )
}

/** The same list folded into a disclosure, for the widths with no third column. */
export function DocsTocFold({ headings }: { headings: Heading[] }) {
  if (headings.length === 0) return null
  return (
    <details className="docs__toc-fold">
      <summary>On this page</summary>
      <TocList headings={headings} active="" />
    </details>
  )
}

function TocList({ headings, active }: { headings: Heading[]; active: string }) {
  return (
    <ul>
      {headings.map((h) => (
        <li key={h.id} data-depth={h.depth}>
          <a href={`#${h.id}`} aria-current={h.id === active ? 'location' : undefined}>
            {h.text}
          </a>
        </li>
      ))}
    </ul>
  )
}
