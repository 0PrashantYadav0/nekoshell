// Facts the page renders, taken from the repository: plugin.toml summaries,
// the command table in README.md, the capability table in docs/TERMINALS.md
// and the profiles in README.md. Change them there first.

export const repo = 'https://github.com/0PrashantYadav0/nekoshell'
export const tap = 'https://github.com/0PrashantYadav0/homebrew-nekoshell'
// The last GitHub Release. The hero asks GitHub for the current one and
// falls back to this when the answer does not arrive.
export const release = '0.2.0'

export type Plugin = { name: string; summary: string; kind: 'core' | 'art' | 'tool' | 'prompt' | 'ai' | 'window' }

export const plugins: Plugin[] = [
  { name: 'modern-cli', summary: 'eza, bat, fd, ripgrep, zoxide and delta, themed to match the shell', kind: 'core' },
  { name: 'greet', summary: 'A Pokémon or your own pixel art next to the machine stats, on every new shell', kind: 'core' },
  { name: 'pokemon', summary: 'A random Pokémon sprite in the greeting, captioned with its number, type and generation', kind: 'art' },
  { name: 'anime', summary: 'A random anime picture in the greeting, drawn inline where the terminal can', kind: 'art' },
  { name: 'minecraft', summary: 'A random Minecraft block in the greeting, from minecraft-colorscripts', kind: 'art' },
  { name: 'colorscripts', summary: "An ANSI pattern in the terminal's own palette in the greeting, from a vetted set of colorscripts", kind: 'art' },
  { name: 'fzf', summary: 'Fuzzy finder key bindings, with previews for files, directories and history', kind: 'tool' },
  { name: 'atuin', summary: 'Shell history you can actually search, kept on this machine', kind: 'tool' },
  { name: 'lazygit', summary: 'A terminal UI for git, in Catppuccin, paged through delta', kind: 'tool' },
  { name: 'btop', summary: 'A resource monitor that follows the theme, on top', kind: 'tool' },
  { name: 'nvim', summary: 'Neovim, themed and configured, without taking over a config you already have', kind: 'tool' },
  { name: 'tmux', summary: 'tmux with a C-a prefix, vim-style panes and the Catppuccin status line', kind: 'tool' },
  { name: 'yazi', summary: 'yazi, a terminal file manager, in the flavour, with y that lands you where you quit', kind: 'tool' },
  { name: 'gh', summary: 'The GitHub CLI, with completions cached for a quick shell and delta as its pager', kind: 'tool' },
  { name: 'mise', summary: 'mise, one tool for every runtime version (node, python, go, ...), activated in every shell', kind: 'tool' },
  { name: 'spotify', summary: 'Spotify in a terminal panel, streaming on its own or driving the desktop app', kind: 'tool' },
  { name: 'pure', summary: "The pure prompt in place of Starship: one line, the path, git, the last command's time", kind: 'prompt' },
  { name: 'p10k', summary: 'Powerlevel10k as the prompt instead of Starship, with your ~/.p10k.zsh and the flavour’s colours', kind: 'prompt' },
  { name: 'omz', summary: "oh-my-zsh's git aliases and web-search, loaded through antidote without oh-my-zsh itself", kind: 'prompt' },
  { name: 'ai', summary: 'A welcome banner for AI coding tools: which tool, which project, which branch, the last commit', kind: 'ai' },
  { name: 'claude-code', summary: 'Claude Code in the flavour: a Catppuccin theme, a status line, and the welcome banner', kind: 'ai' },
  { name: 'opencode', summary: 'OpenCode in the flavour: a Catppuccin theme and the welcome banner', kind: 'ai' },
  { name: 'vscode', summary: 'VS Code opens the nekoshell terminal from Ctrl+Shift+C and the Explorer', kind: 'ai' },
  { name: 'aerospace', summary: 'AeroSpace, an i3-style tiling window manager for macOS', kind: 'window' },
]

export const profiles: { name: string; adds: string[]; note: string }[] = [
  { name: 'minimal', adds: ['modern-cli', 'greet', 'pokemon'], note: 'the shell, the prompt, the greeting' },
  { name: 'dev', adds: ['fzf', 'atuin', 'lazygit', 'btop', 'nvim', 'tmux'], note: 'minimal, plus the tools of a working day' },
  { name: 'full', adds: ['spotify'], note: 'dev, plus music in the panel' },
]

export function profileSet(name: string): Set<string> {
  const out = new Set<string>()
  for (const p of profiles) {
    p.adds.forEach((n) => out.add(n))
    if (p.name === name) break
  }
  return out
}

export const commands: { cmd: string; does: string }[] = [
  { cmd: 'nekoshell install', does: 'link the zshrc, pick a terminal and profile, apply the theme, enable plugins' },
  { cmd: 'nekoshell doctor [--json]', does: 'one line per check; exit 1 only when a check fails' },
  { cmd: 'nekoshell theme list|current|auto|FLAVOUR', does: 'switch or inspect the colour theme' },
  { cmd: 'nekoshell terminal list|use|remove|apply|background', does: 'detect, configure and theme the terminals you use' },
  { cmd: 'nekoshell plugin list|info|add|remove', does: 'manage plugins' },
  { cmd: 'nekoshell music [PLAYER] [--panel]', does: "run the music player here, or in the terminal's panel" },
  { cmd: 'nekoshell greet [--image|--text|--art NAME]', does: 'print the greeting now' },
  { cmd: 'nekoshell art list|add|sample', does: "manage the greeting's art pack" },
  { cmd: 'nekoshell spotify search|client-id|login|logout', does: 'search and play, and your Spotify login' },
  { cmd: 'nekoshell vscode terminal [ID]', does: 'the terminal VS Code opens' },
  { cmd: 'nekoshell ai welcome|edit|status', does: 'the banner in front of AI coding tools' },
  { cmd: 'nekoshell uninstall [--yes] [--purge]', does: 'remove plugins, unlink the zshrc, restore your files' },
]

export type Terminal = { id: string; name: string; images: string; background: string; panel: string; hue: string }

export const terminals: Terminal[] = [
  { id: 'iterm2', name: 'iTerm2', images: 'yes', background: 'yes', panel: '⌥M, from any app (hotkey window)', hue: 'mauve' },
  { id: 'kitty', name: 'kitty', images: 'yes', background: 'yes, PNG (others converted)', panel: 'alt+m, inside kitty', hue: 'peach' },
  { id: 'ghostty', name: 'Ghostty', images: 'yes', background: 'yes', panel: '⌥M, from any app, after Accessibility is granted', hue: 'blue' },
  { id: 'warp', name: 'Warp', images: 'yes', background: 'JPEG only', panel: 'nekoshell music --panel, or the + menu, opens a new window', hue: 'green' },
  { id: 'terminal-app', name: 'Terminal.app', images: 'no', background: 'no', panel: 'nekoshell music --panel opens a new window', hue: 'yellow' },
]

export const shots: { file: string; art: string; caption: string }[] = [
  { file: '/shots/greet-pokemon.png', art: 'pokemon', caption: 'A Pok\u00e9mon sprite, captioned with its number, type and generation. The default provider, in every profile.' },
  { file: '/shots/greet-anime.png', art: 'anime', caption: 'An anime still drawn inline beside the machine stats, the palette swatch under them, the prompt above and below.' },
  { file: '/shots/greet-minecraft.png', art: 'minecraft', caption: 'A Minecraft block from minecraft-colorscripts, as unicode half-blocks, so it works in every terminal.' },
  { file: '/shots/greet-colorscripts.png', art: 'colorscripts', caption: 'An ANSI pattern in the terminal’s own sixteen colours, so it changes with the flavour.' },
]

export const installWays: { id: string; label: string; lines: string[]; note: string }[] = [
  { id: 'brew', label: 'Homebrew tap', lines: ['brew tap 0PrashantYadav0/nekoshell', 'brew install nekoshell', 'nekoshell install'], note: 'The recommended way. Upgrades come through brew upgrade.' },
  { id: 'curl', label: 'One line', lines: ['curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash'], note: 'Clones ~/.nekoshell and runs the installer.' },
  { id: 'git', label: 'Checkout', lines: ['git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell', 'cd ~/.nekoshell', './install.sh'], note: 'What contributors use, since the checkout is the install.' },
]

export const author = {
  name: 'Prashant Kumar Yadav',
  handle: '0PrashantYadav0',
  avatar: 'https://avatars.githubusercontent.com/u/144602492?v=4',
  bio: 'Final year at IIIT Lucknow. Ex software engineering intern at Walmart Global Tech, twice an engineering intern at Eternal, a contributor to stdlib-js, and a four-time hackathon winner. Uses tools to create, not to flex.',
  github: 'https://github.com/0PrashantYadav0',
  portfolio: 'https://prashantyadav.vercel.app',
  x: 'https://x.com/0prashantyadav0',
}
