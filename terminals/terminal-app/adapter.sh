#!/usr/bin/env bash
# Apple Terminal.app. It has no config file of its own to include from: every
# profile lives inside the com.apple.Terminal preferences, under "Window
# Settings", a dictionary of profile name to profile. So the adapter renders
# a .terminal file (one profile as an XML plist) into a directory it owns and
# installs that dictionary into the preferences with `defaults`, which goes
# through cfprefsd and is picked up by a running Terminal without a restart.
# Everything here is a function or one of the constants below;
# terminals/adapter.sh is sourced first and this file overrides what it supports.

TERMINAL_APP_DOMAIN="com.apple.Terminal"
TERMINAL_APP_PROFILE_NAME="nekoshell"
# Overridable so a test can point it at a path that does not exist: the real
# bundle is part of macOS and is always there.
TERMINAL_APP_BUNDLE="${TERMINAL_APP_BUNDLE:-/System/Applications/Utilities/Terminal.app}"
TERMINAL_APP_DIR="${NEKOSHELL_DATA:-$HOME/.local/share/nekoshell}/terminal-app"
TERMINAL_APP_PROFILE="$TERMINAL_APP_DIR/nekoshell.terminal"
TERMINAL_APP_COMMAND="$TERMINAL_APP_DIR/nekoshell-music.command"
# The first macOS whose Terminal.app draws 24-bit colour. Earlier ones round
# every colour to the nearest of 256.
TERMINAL_APP_TRUECOLOR_MAJOR=26
export TERMINAL_APP_DOMAIN TERMINAL_APP_PROFILE_NAME TERMINAL_APP_BUNDLE
export TERMINAL_APP_DIR TERMINAL_APP_PROFILE TERMINAL_APP_COMMAND TERMINAL_APP_TRUECOLOR_MAJOR

terminal_name() { echo "terminal-app"; }
terminal_detect() { [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; }
terminal_installed() { [[ -e "$TERMINAL_APP_BUNDLE" || -e "/Applications/Utilities/Terminal.app" ]]; }
# The PostScript name: Terminal.app archives an NSFont, which is looked up by
# that name rather than the family name other terminals take.
terminal_font_name() { echo "JetBrainsMonoNF-Regular"; }

# terminal_capabilities: a panel always (a new window is a kind of panel);
# truecolor only where Terminal.app really draws it. No images and no
# background image: Terminal.app has neither.
terminal_capabilities() {
  if terminal_app_truecolor; then echo "truecolor panel"; else echo "panel"; fi
}

# Terminal.app has no background image setting. The contract's default says
# exactly this; it is spelled out here because tests/core/repo.bats expects
# every adapter to define all ten functions itself.
terminal_background() { _terminal_unsupported "background"; }

terminal_app_is_running() { pgrep -xq Terminal; }

# terminal_app_needs_restart: true when Terminal.app is running and started
# before the profile file was last written. Terminal reads its profile set
# and the default profile name once, at launch, so a Terminal that was open
# during apply keeps opening windows with the old profile until it is quit
# and reopened. The launch time is Terminal's own LastTerminalStartTime key
# (a UTC datetime); an unreadable one counts as old.
terminal_app_needs_restart() {
  terminal_app_is_running || return 1
  [[ -f "$TERMINAL_APP_PROFILE" ]] || return 1
  local py
  py="$(
    cat <<'PY'
import datetime, os, plistlib, sys
try:
    prefs = plistlib.loads(sys.stdin.buffer.read())
    started = prefs["LastTerminalStartTime"].replace(tzinfo=datetime.timezone.utc).timestamp()
except Exception:
    started = 0
sys.exit(0 if started < os.path.getmtime(sys.argv[1]) else 1)
PY
  )"
  defaults export "$TERMINAL_APP_DOMAIN" - 2>/dev/null | python3 -c "$py" "$TERMINAL_APP_PROFILE"
}

# terminal_app_macos_major: the major version of macOS, or 0 when sw_vers is
# missing or says something unexpected, so a caller can compare it as a number.
terminal_app_macos_major() {
  local v
  v="$(sw_vers -productVersion 2>/dev/null || true)"
  v="${v%%.*}"
  [[ "$v" =~ ^[0-9]+$ ]] || v=0
  printf '%s\n' "$v"
}

terminal_app_truecolor() { [[ "$(terminal_app_macos_major)" -ge "$TERMINAL_APP_TRUECOLOR_MAJOR" ]]; }

# _terminal_app_setting KEY: KEY from nekoshell.toml, or nothing. Tolerates a
# shell where config.sh was never sourced (the adapter is also loadable on its own).
_terminal_app_setting() {
  local v=""
  command -v config_get >/dev/null 2>&1 && v="$(config_get "$1" 2>/dev/null || true)"
  printf '%s' "$v"
}

# terminal_app_default: the name of the profile Terminal opens new windows
# with. Terminal uses "Basic" when the key was never written, so that is what
# an absent key reads as.
terminal_app_default() {
  local d
  d="$(defaults read "$TERMINAL_APP_DOMAIN" "Default Window Settings" 2>/dev/null || true)"
  [[ -n "$d" ]] || d="Basic"
  printf '%s\n' "$d"
}

# terminal_app_installed_font: two tab-separated fields read out of the
# preferences: whether the nekoshell profile is in "Window Settings" (present or
# absent) and the font name its Font archive decodes to. Goes through
# `defaults export` rather than `defaults read`: read prints the archives as
# hex dumps in a format that is not meant to be parsed, export is a plist.
# Status 1 when the preferences could not be read at all.
terminal_app_installed_font() {
  # The script goes in through -c, not `python3 -`: a heredoc would take the
  # place of the piped plist on stdin.
  local py
  py="$(
    cat <<'PY'
import plistlib, sys
try:
    prefs = plistlib.loads(sys.stdin.buffer.read())
    p = prefs.get("Window Settings", {}).get(sys.argv[1])
    if p is None:
        print("absent\t")
        sys.exit(0)
    font = plistlib.loads(p["Font"])
    root = font["$objects"][font["$top"]["root"].data]
    print("present\t" + font["$objects"][root["NSName"].data])
except Exception:
    sys.exit(1)
PY
  )"
  defaults export "$TERMINAL_APP_DOMAIN" - 2>/dev/null | python3 -c "$py" "$TERMINAL_APP_PROFILE_NAME"
}

# terminal_app_defaults_add_profile FILE: put FILE's profile into "Window
# Settings" under its name. `-dict-add` takes the whole XML document as the
# value and replaces an entry of the same name, so a second apply overwrites
# rather than duplicates. A function, so run() prints one short line instead
# of the full XML.
terminal_app_defaults_add_profile() {
  defaults write "$TERMINAL_APP_DOMAIN" "Window Settings" -dict-add "$TERMINAL_APP_PROFILE_NAME" "$(cat "$1")"
}

# terminal_app_defaults_drop_profile: take the nekoshell profile back out of
# "Window Settings". `defaults` cannot delete one key inside a nested
# dictionary, so the whole domain is exported, edited and imported again.
# Nothing but that one entry is touched, and the user's own profiles keep
# their archived fonts and colours byte for byte.
terminal_app_defaults_drop_profile() {
  local py
  py="$(
    cat <<'PY'
import plistlib, sys
prefs = plistlib.loads(sys.stdin.buffer.read())
prefs.get("Window Settings", {}).pop(sys.argv[1], None)
sys.stdout.buffer.write(plistlib.dumps(prefs))
PY
  )"
  defaults export "$TERMINAL_APP_DOMAIN" - | python3 -c "$py" "$TERMINAL_APP_PROFILE_NAME" | defaults import "$TERMINAL_APP_DOMAIN" -
}

# terminal_app_write_profile FLAVOR: regenerate the .terminal file. The flavour
# defaults to mocha so this stays usable without core/lib/theme.sh.
terminal_app_write_profile() {
  local flavor="${1:-mocha}"
  run mkdir -p "$TERMINAL_APP_DIR"
  run python3 "$NEKOSHELL_ROOT/terminals/terminal-app/build-profile.py" \
    --root "$NEKOSHELL_ROOT" \
    --out "$TERMINAL_APP_PROFILE" \
    --flavor "$flavor" \
    --font "$(terminal_font_name)" \
    --size 15
}

# terminal_app_write_command CMD...: the .command file `open -a Terminal` runs
# in a new window. A login shell, so Homebrew's prefix is on PATH for the
# player the command starts. Rewritten only when its content would change, so
# a repeated apply or panel leaves the file's mtime alone.
terminal_app_write_command() {
  local body q
  q="$(printf '%q ' "$@")"
  body="#!/bin/zsh -l
# Written by nekoshell: what \`nekoshell music\` opens in a new Terminal window.
export NEKOSHELL_PANEL=1
exec ${q% }
"
  if [[ -f "$TERMINAL_APP_COMMAND" && "$(cat "$TERMINAL_APP_COMMAND")" == "${body%$'\n'}" ]]; then
    return 0
  fi
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would write $TERMINAL_APP_COMMAND"
    return 0
  fi
  mkdir -p "$TERMINAL_APP_DIR"
  printf '%s' "$body" >"$TERMINAL_APP_COMMAND.tmp"
  chmod +x "$TERMINAL_APP_COMMAND.tmp"
  mv "$TERMINAL_APP_COMMAND.tmp" "$TERMINAL_APP_COMMAND"
}

# terminal_app_remember_default: record the profile new windows opened with
# before nekoshell became it, so terminal_remove can put it back. Skipped when
# it is already nekoshell: the value worth keeping is whatever came before.
terminal_app_remember_default() {
  local prev
  prev="$(terminal_app_default)"
  [[ "$prev" != "$TERMINAL_APP_PROFILE_NAME" ]] || return 0
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would record terminal_app_previous_default = $prev"
  elif command -v config_set >/dev/null 2>&1; then
    config_set terminal_app_previous_default "$prev"
  fi
}

# terminal_apply FLAVOR: render the profile, install it, make it the default
# for new and startup windows, and lay down the .command file the panel opens.
# The preferences go through cfprefsd, so nothing here needs Terminal to be
# closed; but a Terminal that is already running loaded its profiles at
# launch and keeps using them, so it is told to restart.
terminal_apply() {
  local flavor="${1:-mocha}"
  terminal_app_write_profile "$flavor"
  terminal_app_remember_default
  log_info "installing the nekoshell profile into $TERMINAL_APP_DOMAIN"
  run terminal_app_defaults_add_profile "$TERMINAL_APP_PROFILE"
  run defaults write "$TERMINAL_APP_DOMAIN" "Default Window Settings" -string "$TERMINAL_APP_PROFILE_NAME"
  run defaults write "$TERMINAL_APP_DOMAIN" "Startup Window Settings" -string "$TERMINAL_APP_PROFILE_NAME"
  terminal_app_write_command "$NEKOSHELL_ROOT/bin/nekoshell" music --here
  if terminal_app_is_running; then
    log_warn "Terminal.app is running and reads its profiles at launch: quit and reopen it before new windows use nekoshell"
  fi
  terminal_app_truecolor || log_warn "Terminal.app on macOS $(terminal_app_macos_major) draws 256 colours, not 24-bit; the palette will be approximated"
  return 0
}

# terminal_remove: the default profile back to what it was, the nekoshell
# profile out of the preferences, and the owned files gone. The default is
# only restored when it is still nekoshell: a user who has since picked
# another profile keeps it.
terminal_remove() {
  local prev
  if [[ "$(terminal_app_default)" == "$TERMINAL_APP_PROFILE_NAME" ]]; then
    prev="$(_terminal_app_setting terminal_app_previous_default)"
    [[ -n "$prev" ]] || prev="Basic"
    run defaults write "$TERMINAL_APP_DOMAIN" "Default Window Settings" -string "$prev"
    run defaults write "$TERMINAL_APP_DOMAIN" "Startup Window Settings" -string "$prev"
  fi
  case "$(terminal_app_installed_font 2>/dev/null || true)" in
    present*) run terminal_app_defaults_drop_profile ;;
  esac
  run rm -f "$TERMINAL_APP_PROFILE" "$TERMINAL_APP_COMMAND"
  [[ -d "$TERMINAL_APP_DIR" ]] && run rmdir "$TERMINAL_APP_DIR"
  return 0
}

# terminal_panel CMD...: Terminal.app has no split or hotkey API that works
# without an automation prompt, but `open -a Terminal FILE.command` opens a
# new window running the file under the default profile and asks nothing. So
# inside Terminal.app the command goes into the .command file and a window is
# opened on it; inside tmux and everywhere else the shared fallback applies.
terminal_panel() {
  if [[ -n "${TMUX:-}" ]] || ! terminal_detect; then
    terminal_panel_default "$@"
    return $?
  fi
  terminal_app_write_command "$@"
  log_info "opening a new Terminal window for the player"
  run open -a Terminal "$TERMINAL_APP_COMMAND"
}

terminal_doctor() {
  local info="" present="" font="" rc=0 major
  if ! command -v python3 >/dev/null 2>&1; then
    # No parser, so nothing is known about the preferences. That is not
    # evidence the profile is wrong, so it warns rather than failing.
    report warn "terminal-app profile" "python3 missing; $TERMINAL_APP_DOMAIN not checked"
  else
    info="$(terminal_app_installed_font)" || rc=$?
    present="${info%%$'\t'*}"
    font="${info#*$'\t'}"
    if [[ "$rc" -ne 0 ]]; then
      report fail "terminal-app profile" "$TERMINAL_APP_DOMAIN unreadable; run: nekoshell terminal apply"
    elif [[ "$present" == "present" ]]; then
      report ok "terminal-app profile" "nekoshell in Window Settings ($TERMINAL_APP_PROFILE)"
    else
      report fail "terminal-app profile" "missing (run: nekoshell terminal apply)"
    fi
  fi

  if [[ "$(terminal_app_default)" != "$TERMINAL_APP_PROFILE_NAME" ]]; then
    report warn "terminal-app default" "new windows open with $(terminal_app_default); run: nekoshell terminal apply"
  elif terminal_app_needs_restart; then
    report warn "terminal-app default" "nekoshell, but the running Terminal.app started before it was installed; quit and reopen Terminal.app"
  else
    report ok "terminal-app default" "new windows open with nekoshell"
  fi
  case "$font" in
    "$(terminal_font_name)") report ok "terminal-app font" "$font" ;;
    "") report warn "terminal-app font" "no font to read (see the profile row)" ;;
    *) report fail "terminal-app font" "$font is not $(terminal_font_name)" ;;
  esac

  major="$(terminal_app_macos_major)"
  if terminal_app_truecolor; then
    report ok "terminal-app colour" "24-bit colour (macOS $major)"
  else
    report warn "terminal-app colour" "256 colours only on macOS < $TERMINAL_APP_TRUECOLOR_MAJOR (this is $major)"
  fi
}
