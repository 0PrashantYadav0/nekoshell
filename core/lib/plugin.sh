#!/usr/bin/env bash
# Plugin discovery, enable and disable. Needs paths, log, backup, config, link,
# brew, terminal. Source this file; do not execute it.
NEKOSHELL_PLUGINS_DIR="${NEKOSHELL_PLUGINS_DIR:-$NEKOSHELL_ROOT/plugins}"
NEKOSHELL_CORE_ANTIDOTE="${NEKOSHELL_CORE_ANTIDOTE:-$NEKOSHELL_ROOT/core/antidote.txt}"
export NEKOSHELL_PLUGINS_DIR NEKOSHELL_CORE_ANTIDOTE

plugin_dir() { printf '%s/%s\n' "$NEKOSHELL_PLUGINS_DIR" "$1"; }
plugin_exists() { [[ -f "$(plugin_dir "$1")/plugin.toml" ]]; }
plugin_all() {
  local d
  for d in "$NEKOSHELL_PLUGINS_DIR"/*/; do [[ -f "$d/plugin.toml" ]] && basename "$d"; done
  return 0
}
plugin_meta() { toml_get "$(plugin_dir "$1")/plugin.toml" "$2"; }
plugin_meta_list() { toml_list "$(plugin_dir "$1")/plugin.toml" "$2"; }
plugin_enabled() { config_list plugins | grep -Fqx "$1"; }
plugin_enabled_all() { config_list plugins; }

plugin_supports_terminal() {
  local t
  for t in $(plugin_meta_list "$1" terminals); do
    [[ "$t" == "any" || "$t" == "$2" ]] && return 0
  done
  return 1
}

plugin_env() {
  PLUGIN_NAME="$1"
  PLUGIN_DIR="$(plugin_dir "$1")"
  # The flavour in force, asked of theme.sh when it is loaded: a machine that
  # recorded a flavour but has not rendered yet must not hand plugins mocha.
  if command -v theme_current >/dev/null 2>&1; then
    FLAVOR="$(theme_current 2>/dev/null || echo "$NEKOSHELL_DEFAULT_FLAVOR")"
  else
    FLAVOR="$(config_get theme_resolved 2>/dev/null || echo "${NEKOSHELL_DEFAULT_FLAVOR:-mocha}")"
  fi
  export PLUGIN_NAME PLUGIN_DIR FLAVOR
}

# plugin_run_hook NAME HOOK: run plugins/NAME/HOOK.sh in a subshell with the libs loaded.
plugin_run_hook() {
  local hook
  hook="$(plugin_dir "$1")/$2.sh"
  [[ -f "$hook" ]] || return 0
  (
    plugin_env "$1"
    set -euo pipefail
    # shellcheck source=/dev/null
    source "$hook"
  )
}

# plugin_regen_antidote: core/antidote.txt + every enabled plugin's antidote.txt.
plugin_regen_antidote() {
  local out="$NEKOSHELL_CONFIG/antidote.txt" p f
  mkdir -p "$NEKOSHELL_CONFIG"
  {
    [[ -r "$NEKOSHELL_CORE_ANTIDOTE" ]] && cat "$NEKOSHELL_CORE_ANTIDOTE"
    for p in $(plugin_enabled_all); do
      f="$(plugin_dir "$p")/antidote.txt"
      [[ -r "$f" ]] && cat "$f"
    done
    true
  } >"$out.tmp" && mv "$out.tmp" "$out"
}

plugin_providing_cmd() {
  local d
  for d in "$NEKOSHELL_PLUGINS_DIR"/*/; do
    [[ -f "$d/cmd/$1.sh" ]] && {
      basename "$d"
      return 0
    }
  done
  return 0
}

_plugin_doctor_rows() {
  local hook
  hook="$(plugin_dir "$1")/doctor.sh"
  [[ -f "$hook" ]] || return 0
  (
    plugin_env "$1"
    # shellcheck disable=SC2317,SC2329 # invoked indirectly by the sourced doctor.sh (2317 is the code before 0.10)
    report() { printf '%-4s %-28s %s\n' "$1" "$2" "$3"; }
    # shellcheck source=/dev/null
    source "$hook"
  )
}

plugin_add() {
  local name="$1" term dep c t g skip_copy=0
  plugin_exists "$name" || {
    log_fail "no plugin named $name (nekoshell plugin list)"
    return 1
  }
  term="$(terminal_current || true)"
  if [[ -n "$term" ]] && ! plugin_supports_terminal "$name" "$term"; then
    log_fail "$name works on: $(plugin_meta_list "$name" terminals | tr '\n' ' ')(you use $term)"
    return 1
  fi
  for c in $(plugin_meta_list "$name" conflicts); do
    plugin_enabled "$c" && {
      log_fail "$name conflicts with $c; remove it first"
      return 1
    }
  done
  for dep in $(plugin_meta_list "$name" requires_plugins); do
    plugin_enabled "$dep" || {
      log_info "$name needs $dep; adding it first"
      plugin_add "$dep" || return 1
    }
  done
  log_head "$name: $(plugin_meta "$name" summary)"
  for t in $(plugin_meta_list "$name" taps); do brew_tap "$t"; done
  local formulas=() casks=() f
  while IFS= read -r f; do [[ -n "$f" ]] && formulas+=("$f"); done < <(plugin_meta_list "$name" requires)
  while IFS= read -r f; do [[ -n "$f" ]] && casks+=("$f"); done < <(plugin_meta_list "$name" casks)
  if [[ ${#formulas[@]} -gt 0 ]]; then
    brew_install "${formulas[@]}" || {
      log_fail "$name: Homebrew install failed"
      return 1
    }
  fi
  if [[ ${#casks[@]} -gt 0 ]]; then
    brew_cask_install "${casks[@]}" || {
      log_fail "$name: Homebrew install failed"
      return 1
    }
  fi
  link_tree "$(plugin_dir "$name")/files/link" "$HOME" || {
    log_fail "$name: linking files failed"
    return 1
  }
  # copy_guard: paths (relative to $HOME) that mean the user already has a
  # config of their own for this plugin. copy_once alone would keep each file
  # it finds, but a plugin's copy tree is a set: half of ours layered under an
  # existing init.lua or tmux.conf is worse than none of it. One guard path
  # present skips the whole copy, loudly, and the files stay readable in the
  # checkout for anyone who wants to merge them by hand.
  for g in $(plugin_meta_list "$name" copy_guard); do
    if [[ -e "$HOME/$g" ]]; then
      log_warn "$name: $g exists; left your config alone (see plugins/$name/files/copy)"
      skip_copy=1
    fi
  done
  if [[ "$skip_copy" -eq 0 ]]; then
    copy_once "$(plugin_dir "$name")/files/copy" "$HOME" || {
      log_fail "$name: copying files failed"
      return 1
    }
  fi
  plugin_run_hook "$name" install || return 1
  # A dry run stops here. Everything above reports through run() and changes
  # nothing; everything below writes straight to disk - the theme hooks render
  # their files themselves, and config_list_add and plugin_regen_antidote would
  # leave the toml and antidote.txt claiming a plugin that was never installed.
  # The doctor rows go with them: they would report on something that is not
  # there.
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would enable $name"
    return 0
  fi
  plugin_run_hook "$name" theme || return 1
  config_list_add plugins "$name"
  plugin_regen_antidote
  # Rows are informational here: a doctor.sh whose last command is a guarded,
  # legitimately-false check (see tests/fixtures/plugins/flaky-doctor) must
  # not abort plugin_add under set -e after the plugin is already recorded.
  _plugin_doctor_rows "$name" || true
  log_ok "$name enabled"
}

# plugin_remove NAME [purge]
plugin_remove() {
  local name="$1" purge="${2:-}" other f
  plugin_exists "$name" || {
    log_fail "no plugin named $name"
    return 1
  }
  plugin_enabled "$name" || {
    log_warn "$name is not enabled"
    return 0
  }
  for other in $(plugin_enabled_all); do
    [[ "$other" == "$name" ]] && continue
    plugin_meta_list "$other" requires_plugins | grep -Fqx "$name" && {
      log_fail "$other needs $name; remove $other first"
      return 1
    }
  done
  plugin_run_hook "$name" uninstall || return 1
  unlink_tree "$(plugin_dir "$name")/files/link" "$HOME"
  # As in plugin_add: the writes below are not gated by run(), and under a dry
  # run the plugin is still recorded as enabled, so the purge pass would find
  # every formula still needed by "itself" and report nothing useful.
  if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
    log_info "would remove $name"
    return 0
  fi
  config_list_remove plugins "$name"
  plugin_regen_antidote
  if [[ "$purge" == "purge" ]]; then
    for f in $(plugin_meta_list "$name" requires); do
      _plugin_formula_needed_elsewhere "$f" && continue
      brew_has "$f" && run brew uninstall "$f"
    done
  fi
  log_ok "$name removed (its copied configs are still yours)"
}

_plugin_formula_needed_elsewhere() {
  local p
  for p in $(plugin_enabled_all); do plugin_meta_list "$p" requires | grep -Fqx "$1" && return 0; done
  return 1
}
