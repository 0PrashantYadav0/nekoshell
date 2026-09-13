#!/usr/bin/env bash
# Catppuccin flavours. Every themed file is rendered from core/theme/palettes.json,
# so one palette is the only place a colour is written down.
# Requires paths.sh. theme_flavors, theme_is_flavor, theme_title, theme_setting,
# theme_resolve and theme_current need nothing else; theme_render_template and
# theme_write_zsh also want log.sh (log_fail); theme_apply additionally wants
# config.sh, terminal.sh and plugin.sh.
# Source this file; do not execute it.

NEKOSHELL_DEFAULT_FLAVOR="mocha"
export NEKOSHELL_DEFAULT_FLAVOR

# theme_flavors: the known flavours, one per line, sorted. Read from the palette
# file so adding a flavour there is the only edit a new flavour needs.
theme_flavors() {
  python3 -c 'import json,sys
for f in sorted(json.load(open(sys.argv[1]))): print(f)' "$NEKOSHELL_ROOT/core/theme/palettes.json"
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

# theme_hexes FLAVOR ROLE...: print each role's hex, one per line, in the order asked.
theme_hexes() {
  local flavor="$1"
  shift
  python3 -c 'import json,sys
p = json.load(open(sys.argv[1]))[sys.argv[2]]
for role in sys.argv[3:]: print(p[role])' "$NEKOSHELL_ROOT/core/theme/palettes.json" "$flavor" "$@"
}

# theme_render_template SRC DST FLAVOR: copy SRC to DST with the @@...@@
# placeholders replaced by FLAVOR's values. render.py builds the whole file in
# memory and writes it to a temp file next to DST before renaming it into
# place, so a failure part way through (a bad placeholder, a full disk) can
# never leave DST holding a half-written config.
theme_render_template() {
  python3 "$NEKOSHELL_ROOT/core/theme/render.py" "$NEKOSHELL_ROOT/core/theme/palettes.json" "$1" "$2" "$3"
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

# NEKOSHELL_THEME_MARKER: the word every config rendered from one of our
# templates carries in the header comment at the top of the rendered file
# (~/.config/starship.toml names nekoshell on its first line, the fastfetch
# config a few lines in). It is how a file we wrote is told apart from one the
# user wrote, so both theme_apply and the greet theme hook ask the same
# question in the same way.
NEKOSHELL_THEME_MARKER="nekoshell"
export NEKOSHELL_THEME_MARKER

# theme_is_rendered FILE: true when FILE's header names nekoshell, i.e. we
# rendered it. Read into a variable rather than piped into grep: grep -q leaves
# on the first match, and under `set -o pipefail` the SIGPIPE that lands on
# head would turn a match into a non-zero status.
theme_is_rendered() {
  local head=""
  [[ -f "$1" ]] || return 1
  head="$(head -n 10 "$1" 2>/dev/null || true)"
  case "$head" in *"$NEKOSHELL_THEME_MARKER"*) return 0 ;; esac
  return 1
}

# theme_backup_foreign FILE: move FILE into the backup set when it is a regular
# file of the user's that a render is about to replace. Rendering writes over
# whatever is at the path, so without this a hand-written ~/.config/starship.toml
# (or fastfetch config.jsonc) is gone with nothing to restore on uninstall.
#
# A file we rendered ourselves is not backed up: re-running install or switching
# flavour must not fill the backup root with copies of our own output. That also
# makes this back up a hand-replaced file exactly once - the render that follows
# leaves one of ours in its place, which the next run recognises.
#
# Symlinks are left alone: theme_clear_stale_link has already dealt with the
# ones that are ours, and one of the user's is their dotfiles setup, which
# link_tree and backup_path handle where they are linked.
theme_backup_foreign() {
  local file="$1" rel
  [[ -f "$file" && ! -L "$file" ]] || return 0
  if theme_is_rendered "$file"; then return 0; fi
  case "$file" in
    "$HOME"/*) rel="${file#"$HOME"/}" ;;
    *) return 0 ;;
  esac
  # `nekoshell theme` has no backup set of its own; install always does.
  [[ -n "${NEKOSHELL_BACKUP_DIR:-}" ]] || backup_begin
  log_info "backing up your $rel before rendering ours"
  backup_path "$rel"
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
  local flavor="$1" title hexes=() h dest="$NEKOSHELL_CONFIG/theme.zsh"
  title="$(theme_title "$flavor")"
  while IFS= read -r h; do hexes+=("$h"); done < <(
    theme_hexes "$flavor" surface0 base rosewater red text mauve lavender surface1 overlay0
  )
  [[ "${#hexes[@]}" -eq 9 ]] || {
    log_fail "palette lookup failed for $flavor"
    return 1
  }
  # Built on a temp file beside the destination and renamed into place: a
  # failure part way through (a full disk) must not leave a half-written
  # theme.zsh, which every new shell sources.
  cat >"$dest.tmp" <<EOF
# Generated by nekoshell. Changed by \`nekoshell theme <flavour>\`, not by hand:
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
  mv "$dest.tmp" "$dest"
}

# theme_setting: the raw setting recorded in nekoshell.toml, which may be "auto".
theme_setting() { config_get theme 2>/dev/null || echo "$NEKOSHELL_DEFAULT_FLAVOR"; }

# theme_resolve: the flavour "auto" resolves to right now. Follows the macOS
# appearance (dark/light), with the pair it maps to configurable through
# theme_auto_dark/theme_auto_light.
theme_resolve() {
  local s dark light
  s="$(theme_setting)"
  if [[ "$s" != "auto" ]]; then
    echo "$s"
    return 0
  fi
  dark="$(config_get theme_auto_dark 2>/dev/null || echo mocha)"
  light="$(config_get theme_auto_light 2>/dev/null || echo latte)"
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" == "Dark" ]]; then echo "$dark"; else echo "$light"; fi
}

# theme_current: the flavour actually in force, resolved. Prefers the recorded
# theme_resolved (what the last theme_apply actually rendered); falls back to
# resolving theme_setting fresh when nothing valid is recorded yet.
theme_current() {
  local r
  r="$(config_get theme_resolved 2>/dev/null || true)"
  theme_is_flavor "$r" && {
    echo "$r"
    return
  }
  theme_resolve
}

# theme_apply FLAVOR: the whole render — core targets, the current terminal's
# adapter, then every enabled plugin's theme hook. A terminal or plugin hook
# that fails only warns: it must not take the prompt and shell colours down
# with it.
theme_apply() {
  local flavor="$1" term p
  theme_is_flavor "$flavor" || {
    log_fail "unknown flavour: $flavor"
    return 1
  }
  # A dry run reports and writes nothing: every step below (the renders, the
  # recorded theme_resolved, the terminal and the plugin hooks) writes straight
  # to disk rather than through run(), so the gate has to be here.
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would render $flavor"
    return 0
  fi
  mkdir -p "$NEKOSHELL_CONFIG" "$HOME/.config"
  theme_clear_stale_link "$HOME/.config/starship.toml"
  theme_backup_foreign "$HOME/.config/starship.toml"
  theme_render_template "$NEKOSHELL_ROOT/core/starship/starship.toml.tmpl" "$HOME/.config/starship.toml" "$flavor"
  theme_write_zsh "$flavor"
  config_set theme_resolved "$flavor"
  term="$(terminal_current || true)"
  if [[ -n "$term" ]] && terminal_load "$term"; then terminal_apply "$flavor" || log_warn "terminal $term: theme not applied"; fi
  for p in $(plugin_enabled_all); do plugin_run_hook "$p" theme || log_warn "$p: theme hook failed"; done
  log_ok "theme: $flavor"
}
