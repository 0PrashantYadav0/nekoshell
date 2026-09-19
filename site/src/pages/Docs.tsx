import { useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { Background } from '../components/Background'
import { Nav } from '../components/Nav'
import { Footer } from '../components/Footer'
import { DocsMarkdown } from '../components/DocsMarkdown'
import { DocsSidebar } from '../components/DocsSidebar'
import { DocsToc, DocsTocFold } from '../components/DocsToc'
import { pageBySlug, pages, repoBlob } from '../lib/docs'
import { NotFound } from './NotFound'
import '../docs.css'

export default function Docs() {
  const { pathname, hash } = useLocation()
  const slug = pathname.replace(/^\/docs\/?/, '')
  const page = pageBySlug(slug)
  const [sideOpen, setSideOpen] = useState(false)

  useEffect(() => {
    if (page) document.title = `${page.title} · nekoshell docs`
  }, [page])

  // A route change lands at the top; a fragment lands at its heading, once the
  // article that holds it has rendered.
  useEffect(() => {
    if (!page) return
    if (hash) document.getElementById(decodeURIComponent(hash.slice(1)))?.scrollIntoView()
    else window.scrollTo(0, 0)
  }, [pathname, hash, page])

  if (!page) return <NotFound />

  const at = pages.findIndex((p) => p.slug === page.slug)
  const previous = at > 0 ? pages[at - 1] : undefined
  const next = at >= 0 && at < pages.length - 1 ? pages[at + 1] : undefined

  return (
    <>
      <a className="skip" href="#docs-article">Skip to content</a>
      <Background />
      <Nav />
      <div className="docs" data-side={sideOpen}>
        <div className="docs__in">
          <button type="button" className="btn docs__pages" onClick={() => setSideOpen(!sideOpen)} aria-expanded={sideOpen}>
            Pages
          </button>
          <div className="docs__grid">
            <DocsSidebar onNavigate={() => setSideOpen(false)} />
            <article className="docs__article" id="docs-article">
              <h1>{page.title}</h1>
              <DocsTocFold headings={page.headings} />
              <DocsMarkdown body={page.body} source={page.source} />
              <div className="docs__end">
                <a className="docs__edit" href={`${repoBlob}/${page.source}`} target="_blank" rel="noreferrer">
                  Edit this page on GitHub
                </a>
                <div className="docs__steps">
                  {previous && (
                    <Link className="docs__step" to={previous.route}>
                      <span>Previous</span>
                      {previous.title}
                    </Link>
                  )}
                  {next && (
                    <Link className="docs__step docs__step--next" to={next.route}>
                      <span>Next</span>
                      {next.title}
                    </Link>
                  )}
                </div>
              </div>
            </article>
            <DocsToc key={page.slug} headings={page.headings} />
          </div>
        </div>
      </div>
      <Footer />
    </>
  )
}
