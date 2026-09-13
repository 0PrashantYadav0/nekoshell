# Ghostty

## What it configures

`nekoshell terminal apply` renders `~/.config/ghostty/nekoshell` from `terminals/ghostty/nekoshell.tmpl`: JetBrainsMono Nerd Font at 15pt, the Catppuccin flavour in force as foreground, background, cursor, selection and ANSI 0 to 15, 12pt window padding, option as alt, and the quick terminal docked on the right with a global ⌥M keybind that toggles it. Ghostty reads that file through one line in its main config, `~/.config/ghostty/config`: a `# nekoshell` comment followed by `config-file = nekoshell`. The main config is created when there is none and backed up once before its first edit; put your own overrides below that line, since Ghostty applies an included file after the file that names it. Colours come from `core/theme/palettes.json`, so `nekoshell theme latte` re-renders the file and Ghostty picks it up on ⌘⇧, or the next launch.

Ghostty has no config keys for tab bar colours or link colours, so those parts of the shared palette are not written; the macOS native tab bar follows the window background.

## Panel

Ghostty's quick terminal cannot be handed a command, so the panel is the quick terminal plus a shell hook. ⌥M, from any app, slides the quick terminal in on the right. The shell that starts in it sources `terminals/ghostty/zsh.zsh`, which, in a quick terminal, replaces itself with `nekoshell music --here`. Set `ghostty_quick_terminal = "shell"` in `~/.config/nekoshell/nekoshell.toml` to keep it a plain shell. `nekoshell music` outside tmux prints the key and runs the player in the current window; inside tmux it opens a popup.

## Images

Ghostty draws the kitty graphics protocol, so the greet plugin passes fastfetch `--kitty` and the Pokémon appears inline. `nekoshell terminal background PATH [OPACITY]` writes `background-image`, `background-image-opacity` and `background-image-fit = cover` into the owned file, records the path in nekoshell.toml so a theme switch keeps it, and `none` drops it. The path is made absolute first, since Ghostty resolves a relative one against its own working directory. PNG and JPEG only, and Ghostty keeps a copy of the image per terminal, so a large one costs VRAM in every split.

## Uninstall

`nekoshell uninstall` deletes `~/.config/ghostty/nekoshell` and strips the `# nekoshell` line and the `config-file = nekoshell` line under it from the main config. The main config itself is deleted only when nothing else is in it, which is the file nekoshell created; one with your own lines stays. The backup of a main config that existed before nekoshell is restored with the rest of the backup set.

## Known limits

Ghostty reloads its config on ⌘⇧, or on restart, and `quick-terminal-position` in particular only takes effect after a full restart, so the first apply wants a restart. The global ⌥M keybind works only once Ghostty has Accessibility permission (System Settings > Privacy & Security > Accessibility); Ghostty asks for it when it launches with a `global:` keybind, and the doctor cannot see whether it was granted, so the hotkey row stays a warning. There is one quick terminal per Ghostty, so if you use it for something else the music player takes it over unless `ghostty_quick_terminal` is `"shell"`. No live change: a new background or flavour shows after a reload, not in the running window.
