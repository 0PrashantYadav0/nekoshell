import { useEffect, useState } from 'react'
import { release, repo } from '../data/content'

export type Release = { version: string; url: string }

// What the page shows until GitHub answers, and what it keeps showing when
// GitHub does not: the release the repository was last cut at.
export const knownRelease: Release = { version: release, url: `${repo}/releases/latest` }

export const latestEndpoint = 'https://api.github.com/repos/0PrashantYadav0/nekoshell/releases/latest'

// Releases are tagged `v0.3.0`; the page prints the version without the v.
export function versionOfTag(tag: unknown): string | null {
  if (typeof tag !== 'string') return null
  const m = /^v?(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)$/.exec(tag.trim())
  return m ? m[1] : null
}

// One request, four seconds, and no consequence when it fails: an offline
// reader, a rate-limited API and a tag in another shape all end up on the
// release the page already knows.
export async function latestRelease(fetcher: typeof fetch = fetch, timeoutMs = 4000): Promise<Release> {
  const stop = new AbortController()
  const timer = setTimeout(() => stop.abort(), timeoutMs)
  try {
    const res = await fetcher(latestEndpoint, { headers: { Accept: 'application/vnd.github+json' }, signal: stop.signal })
    if (!res.ok) return knownRelease
    const body = (await res.json()) as { tag_name?: unknown; html_url?: unknown }
    const version = versionOfTag(body.tag_name)
    if (!version) return knownRelease
    return { version, url: typeof body.html_url === 'string' ? body.html_url : knownRelease.url }
  } catch {
    return knownRelease
  } finally {
    clearTimeout(timer)
  }
}

// Asked once per mount, and never again: the hero has a release to print
// from its first frame either way.
export function useRelease(): Release {
  const [current, setCurrent] = useState(knownRelease)
  useEffect(() => {
    let live = true
    latestRelease().then((r) => {
      if (live) setCurrent(r)
    })
    return () => {
      live = false
    }
  }, [])
  return current
}
