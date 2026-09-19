import { useState } from 'react'
import { Link } from 'react-router-dom'
import { SectionHead } from './SectionHead'
import { CopyButton } from './CopyButton'
import { installWays, plugins, profiles, profileSet } from '../data/content'

export function Install() {
  const [way, setWay] = useState(installWays[0])
  return (
    <section className="section" id="install">
      <div className="wrap">
        <SectionHead title="Install in a minute" sub="You need macOS, Homebrew, zsh and git. The installer fetches Starship, antidote and the font itself, asks which terminal and which profile, and backs up every file it replaces." />
        <div className="install">
          <div>
            <div className="seg" role="tablist" aria-label="Ways to install">
              {installWays.map((w) => (
                <button key={w.id} role="tab" aria-selected={way.id === w.id} onClick={() => setWay(w)}>
                  {w.label}
                  {w.id === 'brew' && <span className="badge">Recommended</span>}
                </button>
              ))}
            </div>
            <div className="way" role="tabpanel">
              <pre>{way.lines.map((l) => <span key={l}>{l}{'\n'}</span>)}</pre>
              <CopyButton text={way.lines.join('\n')} label={`Copy the ${way.label} commands`} />
            </div>
            <p className="way__note">{way.note} Re-running is safe; <code>nekoshell doctor</code> tells you what is left. Uninstalling puts every backed-up file back: <Link to="/docs/install">the install page</Link>.</p>
            <h3 className="profile-list__head">What a profile installs</h3>
            <ul className="profile-list">
              {profiles.map((p) => (
                <li key={p.name}>
                  <b>{p.name}</b>
                  <span className="profile-list__count">{profileSet(p.name).size} of {plugins.length} plugins</span>
                  <span className="profile-list__adds">{p.note}: {p.adds.join(', ')}</span>
                </li>
              ))}
            </ul>
            <p className="profile-list__note"><code>--profile</code> picks one of the three; <code>--with a,b</code> and <code>--without c</code> adjust the list it installs.</p>
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
