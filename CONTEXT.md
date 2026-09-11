# nekoshell

The shared vocabulary for an open-source iTerm2 + zsh setup that greets you with art and machine stats, docks Spotify in a side panel, and installs itself from the repo. Working name; see wayfinder ticket 0001.

## Language

**Rig**:
The complete installed result on one machine: terminal profile, shell, prompt, tools, greeting and panel together.
_Avoid_: Setup, config, dotfiles (dotfiles are one part of the rig)

**Greeting**:
What a new interactive terminal prints before the first prompt: one piece of art beside the machine stats.
_Avoid_: Banner, splash, MOTD, fetch

**Art**:
The image or colourscript shown in the greeting. Either a Pokémon colourscript or a picture from the art pack.
_Avoid_: Logo, wallpaper, pic

**Art pack**:
The folder of user-supplied images the greeting can draw from. The repo ships only openly licensed samples in it.
_Avoid_: Image library, assets

**Stats**:
The machine facts printed next to the art (host, OS, shell, terminal, CPU, memory, uptime, packages).
_Avoid_: Sysinfo, specs, fetch output

**Panel**:
The Spotify side window that one global hotkey shows and hides, docked to the right edge of the screen.
_Avoid_: Side tab, split, drawer, popup

**Hotkey**:
The single global key combination that toggles the panel from any app.
_Avoid_: Shortcut, keybinding (keybindings are in-terminal keys, hotkeys work system-wide)

**Theme**:
One named colour palette applied consistently to every part of the rig.
_Avoid_: Colorscheme, skin, look

**Flavour**:
One of the four Catppuccin themes the rig can wear: latte, frappe, macchiato or mocha. The flavour in force is recorded in `~/.config/nekoshell/theme`.
_Avoid_: Variant, mode, dark/light

**Profile**:
An iTerm2 profile shipped as a dynamic profile JSON file. The rig has two: the main profile and the panel profile.
_Avoid_: Preset, settings

**Status bar**:
The row iTerm2 draws along the bottom of a main-profile window: working directory and git branch on the left, machine and clock components on the right. Configured as a `Status Bar Layout` dictionary inside the profile.
_Avoid_: Statusline, footer, tab bar (the tab bar is hidden)

**Shell integration**:
iTerm2's own zsh hooks at `~/.iterm2_shell_integration.zsh`, downloaded by the installer. They report the working directory and the last command's status to iTerm2, which is what the status bar's first two components read.
_Avoid_: Hooks, iTerm hooks, integration script

**Installer**:
The idempotent script that turns a fresh machine into the rig, and can be re-run safely.
_Avoid_: Bootstrap, setup script

**Doctor**:
The check command whose output proves the rig is installed and working. The agent install contract requires it to pass.
_Avoid_: Health check, verify, test

**Agent install contract**:
The set of documents (AGENTS.md, INSTALL.md) that let an AI agent install the rig unattended, including the exact prompts only a human can answer.
_Avoid_: AI guide, cloud guide (meaning still open, see ticket 0009)
