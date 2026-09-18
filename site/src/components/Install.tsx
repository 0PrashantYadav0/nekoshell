import { useState } from 'react'
import { Prompt } from './Prompt'
import { installWays, repo } from '../data/content'
import { useCopy } from '../lib/motion'

export function Install() {
  const [way, setWay] = useState(installWays[0])
  const [done, copy] = useCopy()
  return (
    <section className="section" id="install">
      <div className="wrap">
        <Prompt cmd="brew install" args="nekoshell" out={<>macOS, Homebrew, zsh and git; the installer fetches Starship, antidote and the font itself, asks which terminal and which profile, and backs up every file it replaces</>} />
        <div className="ways" role="tablist" aria-label="Ways to install">
          {installWays.map((w) => (
            <button key={w.id} role="tab" aria-selected={way.id === w.id} onClick={() => setWay(w)}>{w.label}</button>
          ))}
        </div>
        <div className="way" role="tabpanel">
          <pre>{way.lines.map((l) => <span key={l}>{l}{'\n'}</span>)}</pre>
          <button className="copy" data-done={done} onClick={() => copy(way.lines.join('\n'))}>{done ? 'copied' : 'copy'}</button>
          <p className="way__note">{way.note} Re-running is safe. <code>nekoshell doctor</code> tells you what is left.</p>
        </div>
        <div className="install__after">
          <div><b>iTerm2</b>Quit it once and run <code>nekoshell terminal apply</code>, so the global preferences land.</div>
          <div><b>Ghostty</b>Grant Accessibility in System Settings, or ⌥M does nothing.</div>
          <div><b>Terminal.app</b>Quit and reopen it; it reads its profiles at launch.</div>
        </div>
        <p className="themes__note">
          Everything else the installer prints at the end. Uninstalling puts every backed-up file back: <a href={`${repo}/blob/main/docs/INSTALL.md`} target="_blank" rel="noreferrer">docs/INSTALL.md</a>.
        </p>
      </div>
    </section>
  )
}
