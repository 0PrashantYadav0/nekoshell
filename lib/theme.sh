#!/usr/bin/env bash
# Catppuccin flavours. Every themed file is rendered from data/palettes.json, so
# one palette is the only place a colour is written down.
# Requires lib/paths.sh. theme_flavors, theme_is_flavor, theme_title and
# theme_current need nothing else; the rendering functions also want lib/log.sh
# (run_quiet), lib/backup.sh (backup_link_target) and lib/iterm.sh
# (iterm_write_profiles).
# Source this file; do not execute it.

NEKOSHELL_DEFAULT_FLAVOR="mocha"
export NEKOSHELL_DEFAULT_FLAVOR

# theme_flavors: the known flavours, one per line, sorted. Read from the palette
# file so adding a flavour there is the only edit a new flavour needs.
theme_flavors() {
  python3 -c 'import json,sys
for f in sorted(json.load(open(sys.argv[1]))): print(f)' "$NEKOSHELL_ROOT/data/palettes.json"
}

# theme_is_flavor NAME: true when NAME is one of them. A loop rather than a pipe
# into `grep -q`: grep leaves early on a match, and under `set -o pipefail` the
# SIGPIPE that lands on python3 would turn a match into a non-zero status.
theme_is_flavor() {
  local f found=1
  [[ -n "${1:-}" ]] || return 1
  while IFS= read -r f; do
    [[ "$f" == "$1" ]] && found=0
  done < <(theme_flavors)
  return "$found"
}

# theme_current: the flavour in force, or the default when nothing is recorded.
theme_current() {
  local f=""
  [[ -r "$NEKOSHELL_CONFIG/theme" ]] && f="$(cat "$NEKOSHELL_CONFIG/theme")"
  if theme_is_flavor "$f"; then printf '%s\n' "$f"; else printf '%s\n' "$NEKOSHELL_DEFAULT_FLAVOR"; fi
}

# theme_hexes FLAVOR ROLE...: print each role's hex, one per line, in the order asked.
theme_hexes() {
  local flavor="$1"; shift
  python3 -c 'import json,sys
p = json.load(open(sys.argv[1]))[sys.argv[2]]
for role in sys.argv[3:]: print(p[role])' "$NEKOSHELL_ROOT/data/palettes.json" "$flavor" "$@"
}

# theme_render_template SRC DST FLAVOR: copy SRC to DST with the @@...@@
# placeholders replaced by FLAVOR's values. The whole file is written at once, so
# a failure part way through cannot leave half a config behind.
theme_render_template() {
  python3 -c '
import json, sys
palettes, src, dst, flavor = sys.argv[1:5]
p = json.load(open(palettes))[flavor]


def sgr(role):
    h = p[role]
    return "38;2;%d;%d;%d" % tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


with open(src, encoding="utf-8") as f:
    text = f.read()
for placeholder, value in (("@@FLAVOR@@", flavor),
                           ("@@KEYS_SGR@@", sgr("mauve")),
                           ("@@TITLE_SGR@@", sgr("blue"))):
    text = text.replace(placeholder, value)
with open(dst, "w", encoding="utf-8") as f:
    f.write(text)
' "$NEKOSHELL_ROOT/data/palettes.json" "$1" "$2" "$3"
}

# theme_clear_stale_link PATH: drop PATH when it is a leftover stow link.
# starship.toml and the fastfetch config used to be stowed. `stow --restow` only
# unlinks what the package still holds, so an upgraded machine keeps the old link
# and a render would write straight into the repo.
#
# Two shapes count as stale, because stow writes relative links and this version
# deleted the directory one of them pointed through:
#
#   1. It resolves to somewhere inside the checkout.
#   2. It is broken. backup_link_target cannot resolve a relative link whose
#      target directory is gone, so shape 1 misses exactly the link an upgrade
#      leaves at ~/.config/fastfetch/config.jsonc. A broken link here can never
#      be a working config of the user's, so removing it loses nothing and the
#      render puts a real file in its place.
#
# A relative link to a real file outside the checkout is the user's own dotfiles
# setup. It is neither shape and is left alone.
theme_clear_stale_link() {
  local p="$1" target
  [[ -L "$p" ]] || return 0
  target="$(backup_link_target "$p" 2>/dev/null || true)"
  if [[ -n "$target" && "$target" == "$NEKOSHELL_ROOT"/* ]] || [[ ! -e "$p" ]]; then
    rm -f "$p"
  fi
  return 0
}

# theme_title FLAVOR: the flavour with its first letter capitalised, the shape
# bat and the Catppuccin theme files spell it in ("mocha" -> "Mocha").
theme_title() {
  printf '%s%s\n' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}

# theme_write_zsh FLAVOR: write ~/.config/nekoshell/theme.zsh, the colour half of
# the shell environment. bat reads BAT_THEME, fzf reads FZF_DEFAULT_OPTS, and the
# bat theme files are named for the flavour with its first letter capitalised.
#
# This file also carries the syntax-highlighting theme, because .zshrc sources it
# (through env.zsh) above the antidote block: zsh-syntax-highlighting reads
# ZSH_HIGHLIGHT_STYLES when it loads, so the styles have to be set before then.
theme_write_zsh() {
  local flavor="$1" title hexes=() h
  title="$(theme_title "$flavor")"
  while IFS= read -r h; do hexes+=("$h"); done < <(
    theme_hexes "$flavor" surface0 base rosewater red text mauve lavender surface1 overlay0)
  [[ "${#hexes[@]}" -eq 9 ]] || { log_fail "palette lookup failed for $flavor"; return 1; }
  cat > "$NEKOSHELL_CONFIG/theme.zsh" <<EOF
# Generated by nekoshell. Changed by \`nekoshell-theme <flavour>\`, not by hand:
# the next theme switch overwrites this file. Your own settings go in
# ~/.config/nekoshell/zsh/local.zsh.
export NEKOSHELL_THEME="$flavor"
export BAT_THEME="Catppuccin $title"
export FZF_DEFAULT_OPTS=" \\
--color=bg+:#${hexes[0]},bg:#${hexes[1]},spinner:#${hexes[2]},hl:#${hexes[3]} \\
--color=fg:#${hexes[4]},header:#${hexes[3]},info:#${hexes[5]},pointer:#${hexes[2]} \\
--color=marker:#${hexes[6]},fg+:#${hexes[4]},prompt:#${hexes[5]},hl+:#${hexes[3]} \\
--color=selected-bg:#${hexes[7]} --multi --height=40% --layout=reverse --border=rounded"
# The suggestion sits behind what you are typing, so it wants the dimmest
# readable colour in the palette rather than a colour of its own.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#${hexes[8]}"
source "$NEKOSHELL_ROOT/data/zsh-syntax-highlighting/catppuccin_$flavor-zsh-syntax-highlighting.zsh"
EOF
}

# theme_build_bat_cache: bat reads themes from its own cache, not from
# ~/.config/bat/themes, so the vendored tmTheme files are invisible until the
# cache is built. Quiet and best effort: a bat that cannot build a cache is a
# plain bat, not a broken install.
theme_build_bat_cache() {
  command -v bat >/dev/null 2>&1 || return 0
  run_quiet bat cache --build || log_warn "bat cache --build failed; bat keeps its old themes"
  return 0
}

# theme_write_btop FLAVOR: point btop at this flavour's vendored theme. btop owns
# the rest of btop.conf and rewrites it on exit, so only the one line is touched.
theme_write_btop() {
  local flavor="$1" conf="$HOME/.config/btop/btop.conf" tmp
  mkdir -p "$HOME/.config/btop"
  if [[ ! -f "$conf" ]]; then
    printf '#? Config file for btop v. 1.x, written by nekoshell.\ncolor_theme = "catppuccin_%s"\n' "$flavor" > "$conf"
  elif grep -q '^color_theme' "$conf"; then
    tmp="$conf.nekoshell.tmp"
    sed "s|^color_theme.*|color_theme = \"catppuccin_$flavor\"|" "$conf" > "$tmp" && mv "$tmp" "$conf"
  else
    printf 'color_theme = "catppuccin_%s"\n' "$flavor" >> "$conf"
  fi
}

# theme_write_tmux FLAVOR: the one line catppuccin/tmux reads for its flavour.
# It is a file of its own rather than a line in the user's tmux.conf, so a
# flavour switch never has to edit a config that belongs to them: their
# tmux.conf sources this, and `tmux source-file ~/.config/tmux/tmux.conf`
# (C-a r) picks up the new colours.
theme_write_tmux() {
  local flavor="$1"
  mkdir -p "$HOME/.config/tmux" || return 1
  printf 'set -g @catppuccin_flavor "%s"\n' "$flavor" > "$HOME/.config/tmux/nekoshell-theme.conf"
}

# theme_apply FLAVOR MODE PROFILE: the whole render.
#   MODE     "keep" leaves an existing starship.toml or fastfetch config alone,
#            because those are the user's files once they exist. "overwrite"
#            rewrites them, which is what switching flavour means.
#   PROFILE  "profile" rewrites the iTerm2 profile too, "no-profile" does not.
#
# Order matters. Everything that can fail runs first: a missing template, an
# unreadable palette or a path that cannot be written must not leave the rig with
# a latte prompt and a mocha terminal. The recorded flavour is written last, so a
# failure anywhere above leaves the previous flavour in force and a non-zero exit.
theme_apply() {
  local flavor="$1" mode="$2" profile="$3" starship="$HOME/.config/starship.toml"
  local fastfetch="$HOME/.config/fastfetch/config.jsonc"
  theme_is_flavor "$flavor" || { log_fail "unknown flavour: $flavor"; return 1; }
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would render the $flavor theme: starship.toml, fastfetch config, btop.conf, theme.zsh, tmux flavour"
    return 0
  fi
  mkdir -p "$NEKOSHELL_CONFIG" "$HOME/.config/fastfetch" || return 1
  theme_clear_stale_link "$starship"
  theme_clear_stale_link "$fastfetch"
  if [[ "$mode" != "keep" || ! -e "$starship" ]]; then
    theme_render_template "$NEKOSHELL_ROOT/templates/starship.toml" "$starship" "$flavor" || return 1
  fi
  if [[ "$mode" != "keep" || ! -e "$fastfetch" ]]; then
    theme_render_template "$NEKOSHELL_ROOT/templates/fastfetch.jsonc" "$fastfetch" "$flavor" || return 1
  fi
  if [[ "$profile" == "profile" ]]; then
    iterm_write_profiles "$flavor" || return 1
  fi
  theme_write_zsh "$flavor" || return 1
  theme_write_btop "$flavor" || return 1
  theme_write_tmux "$flavor" || return 1
  theme_build_bat_cache
  printf '%s\n' "$flavor" > "$NEKOSHELL_CONFIG/theme"
}

# theme_write_files FLAVOR [MODE]: render everything but the iTerm2 profile.
# The installer's entry point; it writes the profile itself, in its own step.
theme_write_files() {
  theme_apply "$1" "${2:-overwrite}" no-profile
}

# theme_render FLAVOR: switch to FLAVOR outright, iTerm2 profile included.
theme_render() {
  theme_apply "$1" overwrite profile
}
