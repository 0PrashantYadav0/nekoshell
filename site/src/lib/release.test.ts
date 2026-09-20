import { describe, expect, it } from 'vitest'
import { knownRelease, latestRelease, versionOfTag } from './release'

// A fetch that never answers, and gives up the way the platform does when the
// AbortController fires.
const hangs: typeof fetch = (_url, init) =>
  new Promise((_resolve, reject) => {
    init?.signal?.addEventListener('abort', () => reject(new DOMException('The operation was aborted.', 'AbortError')))
  })

const answers = (body: unknown, ok = true): typeof fetch => () => Promise.resolve({ ok, json: () => Promise.resolve(body) } as Response)

describe('versionOfTag', () => {
  it('drops the v a release tag carries', () => {
    expect(versionOfTag('v0.3.0')).toBe('0.3.0')
  })

  it('takes a tag written without the v', () => {
    expect(versionOfTag('0.2.0')).toBe('0.2.0')
  })

  it('refuses anything that does not name a version', () => {
    expect(versionOfTag('nightly')).toBeNull()
    expect(versionOfTag(undefined)).toBeNull()
    expect(versionOfTag(3)).toBeNull()
  })
})

describe('latestRelease', () => {
  it('reads the tag and the page GitHub answers with', async () => {
    const res = await latestRelease(answers({ tag_name: 'v0.3.0', html_url: 'https://github.com/0PrashantYadav0/nekoshell/releases/tag/v0.3.0' }))
    expect(res).toEqual({ version: '0.3.0', url: 'https://github.com/0PrashantYadav0/nekoshell/releases/tag/v0.3.0' })
  })

  it('falls back to the known release when the request is refused', async () => {
    const refuses: typeof fetch = () => Promise.reject(new TypeError('Failed to fetch'))
    await expect(latestRelease(refuses)).resolves.toEqual(knownRelease)
  })

  it('falls back to the known release when the request runs out of time', async () => {
    await expect(latestRelease(hangs, 5)).resolves.toEqual(knownRelease)
  })

  it('falls back to the known release on an error status', async () => {
    await expect(latestRelease(answers({ message: 'rate limit' }, false))).resolves.toEqual(knownRelease)
  })

  it('falls back to the known release when the tag is in another shape', async () => {
    await expect(latestRelease(answers({ tag_name: 'nightly' }))).resolves.toEqual(knownRelease)
  })

  it('keeps the releases page when the answer points anywhere else', async () => {
    for (const html_url of ['https://example.com/releases/tag/v0.3.0', 'https://github.com/someone/else/releases/tag/v0.3.0', 'https://github.com/0PrashantYadav0/nekoshell.evil/releases', 42]) {
      await expect(latestRelease(answers({ tag_name: 'v0.3.0', html_url }))).resolves.toEqual({ version: '0.3.0', url: knownRelease.url })
    }
  })
})
