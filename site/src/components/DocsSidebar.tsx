import { useEffect, useMemo, useState } from 'react'
import { NavLink } from 'react-router-dom'
import { groups, type DocPage } from '../lib/docs'

const KEY = 'nekoshell.docs.collapsed'

function readCollapsed(): string[] {
  try {
    const raw = window.localStorage.getItem(KEY)
    return raw ? (JSON.parse(raw) as string[]) : []
  } catch {
    return []
  }
}

function writeCollapsed(labels: string[]) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(labels))
  } catch {
    // A browser that refuses storage still gets a working sidebar.
  }
}

const matches = (page: DocPage, query: string) =>
  page.title.toLowerCase().includes(query) || page.headings.some((h) => h.text.toLowerCase().includes(query))

export function DocsSidebar({ onNavigate }: { onNavigate: () => void }) {
  const [filter, setFilter] = useState('')
  const [collapsed, setCollapsed] = useState<string[]>(readCollapsed)
  useEffect(() => writeCollapsed(collapsed), [collapsed])

  const query = filter.trim().toLowerCase()
  const shown = useMemo(
    () =>
      groups
        .map((g) => ({ label: g.label, pages: query ? g.pages.filter((p) => matches(p, query)) : g.pages }))
        .filter((g) => g.pages.length > 0),
    [query],
  )

  const toggle = (label: string) =>
    setCollapsed((was) => (was.includes(label) ? was.filter((l) => l !== label) : [...was, label]))

  return (
    <nav className="docs__side" id="docs-side" aria-label="Documentation">
      <input
        className="docs__filter"
        type="search"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        placeholder="Filter pages"
        aria-label="Filter pages"
      />
      {shown.length === 0 && <p className="docs__empty">No page matches.</p>}
      {shown.map((group) => {
        // A filter shows what it found, whatever the reader collapsed before.
        const open = !!query || !collapsed.includes(group.label)
        return (
          <section key={group.label} className="docs__group">
            <button type="button" className="docs__group-head" onClick={() => toggle(group.label)} aria-expanded={open}>
              <Chevron open={open} />
              {group.label}
            </button>
            {open && (
              <ul>
                {group.pages.map((page) => (
                  <li key={page.route}>
                    {/* NavLink marks the open page with aria-current="page". */}
                    <NavLink to={page.route} end onClick={onNavigate}>
                      {page.title}
                    </NavLink>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )
      })}
    </nav>
  )
}

function Chevron({ open }: { open: boolean }) {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" data-open={open}>
      <path d="M6 4l4 4-4 4" />
    </svg>
  )
}
