import { useState } from 'react'
import { SectionHead } from './SectionHead'
import { installWays, repo } from '../data/content'
import { useCopy } from '../lib/motion'

export function Install() {
  const [way, setWay] = useState(installWays[0])
  const [done, copy] = useCopy()
  return (
    <section className="section" id="install">
      <div className="wrap">
        <SectionHead title="Install in a minute" sub="You need macOS, Homebrew, zsh and git. The installer fetches Starship, antidote and the font itself, asks which terminal and which profile, and backs up every file it replaces." />
        <div className="install">
          <div>
            <div className="seg" role="tablist" aria-label="Ways to install">
              {installWays.map((w) => (
                <button key={w.id} role="tab" aria-selected={way.id === w.id} onClick={() => setWay(w)}>{w.label}</button>
              ))}
            </div>
            <div className="way" role="tabpanel">
              <pre>{way.lines.map((l) => <span key={l}>{l}{'\n'}</span>)}</pre>
              <button className="copy" data-done={done} onClick={() => copy(way.lines.join('\n'))}>{done ? 'Copied' : 'Copy'}</button>
              <p className="way__note">{way.note} Re-running is safe; <code>nekoshell doctor</code> tells you what is left. Uninstalling puts every backed-up file back: <a href={`${repo}/blob/main/docs/INSTALL.md`} target="_blank" rel="noreferrer">docs/INSTALL.md</a>.</p>
            </div>
          </div>
          <div>
            <h3 className="after-title" style={{ fontSize: 'var(--fs-1)', fontWeight: 600, marginBottom: '0.75rem' }}>After the install</h3>
            <ul className="after">
              <li><b>iTerm2</b>Quit it once and run <code>nekoshell terminal apply</code>, so the global preferences land.</li>
              <li><b>Ghostty</b>Grant Accessibility in System Settings, or ⌥M does nothing.</li>
              <li><b>Terminal.app</b>Quit and reopen it; it reads its profiles at launch.</li>
              <li><b>Warp</b>Sign in; Warp shows nothing until you do.</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  )
}
