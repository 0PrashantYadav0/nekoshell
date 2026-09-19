import { isValidElement, useMemo, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import Markdown, { type Components } from 'react-markdown'
import rehypeSlug from 'rehype-slug'
import remarkGfm from 'remark-gfm'
import { docsHref } from '../lib/docs'
import { CopyButton } from './CopyButton'

// The docs pages are shell and TOML, so there is no highlighter here: it would
// cost hundreds of kilobytes to colour a handful of commands. Code reads in
// the terminal font on the mantle, with the fence's language in the corner.

/** Everything a node renders, flattened to the text it carries. */
function textOf(node: ReactNode): string {
  if (node === null || node === undefined || typeof node === 'boolean') return ''
  if (typeof node === 'string' || typeof node === 'number') return String(node)
  if (Array.isArray(node)) return node.map(textOf).join('')
  if (isValidElement<{ children?: ReactNode }>(node)) return textOf(node.props.children)
  return ''
}

function CodeBlock({ children }: { children?: ReactNode }) {
  const code = isValidElement<{ className?: string; children?: ReactNode }>(children) ? children : null
  const className = code?.props.className ?? ''
  const language = /language-(\S+)/.exec(className)?.[1] ?? ''
  const text = textOf(code ? code.props.children : children).replace(/\n+$/, '')
  return (
    <div className="md__code">
      <div className="md__code-bar">
        <span className="md__lang">{language}</span>
        <CopyButton text={text} />
      </div>
      <pre>
        <code className={className || undefined}>{text}</code>
      </pre>
    </div>
  )
}

const remarkPlugins = [remarkGfm]
const rehypePlugins = [rehypeSlug]

/** react-markdown sanitises urls by default, which would rewrite a relative
 *  link before `docsHref` could map it, so the raw value has to reach the
 *  components below untouched.
 *
 *  The threat model this rests on: the Markdown is a committed copy of this
 *  repository's own documentation, reviewed like any other file here, and
 *  `routeFor` in lib/docs.ts drops every scheme but http, https and mailto, so
 *  a `javascript:` href cannot survive the mapping. Do not point this renderer
 *  at text from anywhere else without putting the sanitiser back. */
const keepUrl = (url: string) => url

/** The components that turn one page's Markdown into the site's own markup. */
function componentsFor(source: string): Components {
  return {
    a({ href, children }) {
      const link = docsHref(href ?? '', source)
      if (!link.href) return <span>{children}</span>
      if (link.external) {
        return (
          <a href={link.href} target="_blank" rel="noreferrer">
            {children}
          </a>
        )
      }
      if (link.href.startsWith('#')) return <a href={link.href}>{children}</a>
      return <Link to={link.href}>{children}</Link>
    },
    img({ src, alt, title }) {
      const link = docsHref(typeof src === 'string' ? src : '', source)
      if (!link.href) return null
      return <img className="md__img" src={link.href} alt={alt ?? ''} title={title} loading="lazy" />
    },
    pre: CodeBlock,
    table({ children }) {
      return (
        <div className="md__table">
          <table>{children}</table>
        </div>
      )
    },
  }
}

export function DocsMarkdown({ body, source }: { body: string; source: string }) {
  const components = useMemo(() => componentsFor(source), [source])
  return (
    <div className="md">
      <Markdown remarkPlugins={remarkPlugins} rehypePlugins={rehypePlugins} urlTransform={keepUrl} components={components}>
        {body}
      </Markdown>
    </div>
  )
}
