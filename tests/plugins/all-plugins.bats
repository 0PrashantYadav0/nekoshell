#!/usr/bin/env bats
# One sweep over every shipped plugin: add it, ask the doctor, remove it, and
# check nothing under HOME still points into the checkout. The per-plugin
# files test what each plugin does; this one catches a plugin whose file
# forgot the basics, and a new plugin added without a test at all.
load ../helpers
setup() {
  setup_tmp_home
  # Two PATHs: most plugins want the general fakes directory, but ai,
  # claude-code and opencode's own bats files use tests/fakes-ai instead,
  # because tests/fakes' git fake would shadow the real git their banner
  # reads the repository with. The sweep switches per plugin below, the same
  # way those files do.
  ORIG_PATH="$PATH"
  FAKES_PATH="$REPO_ROOT/tests/fakes:$ORIG_PATH"
  FAKES_AI_PATH="$REPO_ROOT/tests/fakes-ai:$ORIG_PATH"
  export PATH="$FAKES_PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_TERM=1 FAKE_BREW_INSTALLED="" FAKE_BREW_CASKS="" FAKE_BREW_TAPS=""
  # pure's and p10k's doctors look for what Homebrew installed under
  # $HOMEBREW_PREFIX (then /opt/homebrew, then /usr/local); on a bare CI
  # runner none of that exists, so both would show a doctor "fail" row that
  # only ever passed here because this Mac happens to have the real formulas.
  # pure.bats fakes prompt_pure_setup and async the same way; p10k.bats itself
  # accepts either ok or fail for this row (it does not fake the path), but
  # the sweep wants a deterministic pass regardless of the runner, so it fakes
  # the theme file too.
  export HOMEBREW_PREFIX="$HOME/fakebrew"
  mkdir -p "$HOMEBREW_PREFIX/share/zsh/site-functions"
  printf "PROMPT='pure> '\n" >"$HOMEBREW_PREFIX/share/zsh/site-functions/prompt_pure_setup"
  printf ':\n' >"$HOMEBREW_PREFIX/share/zsh/site-functions/async"
  mkdir -p "$HOMEBREW_PREFIX/share/powerlevel10k"
  printf '# fake powerlevel10k theme file\n' >"$HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
  # anime fetches a real tarball over (faked) curl and checks it against a
  # recorded sha256; anime.bats builds one of its own for the same reason, so
  # the sweep does too, rather than leave anime's install to warn and skip.
  mkdir -p "$HOME/src/anime-colorscripts/colorscripts"
  printf '2997-hatsune-miku\n' >"$HOME/src/anime-colorscripts/charalist.txt"
  printf 'ART 2997-hatsune-miku\nline2\n' >"$HOME/src/anime-colorscripts/colorscripts/2997-hatsune-miku.txt"
  (cd "$HOME/src" && tar czf "$HOME/anime.tar.gz" ./anime-colorscripts)
  export FAKE_CURL_SOURCE="$HOME/anime.tar.gz"
  NEKOSHELL_ANIME_SHA256="$(shasum -a 256 "$HOME/anime.tar.gz" | cut -d' ' -f1)"
  export NEKOSHELL_ANIME_SHA256
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" >"$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
}
teardown() { teardown_tmp_home; }

# links_into_checkout: every symlink under HOME whose target is inside the
# checkout, one per line. Empty after a clean remove.
links_into_checkout() {
  find "$HOME" -type l 2>/dev/null | while IFS= read -r l; do
    case "$(readlink "$l")" in "$REPO_ROOT"/*) printf '%s -> %s\n' "$l" "$(readlink "$l")" ;; esac
  done
}

@test "every shipped plugin adds, passes doctor without a fail row, and removes cleanly" {
  local bad="" dir name out
  for dir in "$REPO_ROOT"/plugins/*/; do
    name="$(basename "$dir")"
    case "$name" in
      ai | claude-code | opencode) PATH="$FAKES_AI_PATH" ;;
      *) PATH="$FAKES_PATH" ;;
    esac
    if ! out="$("$NK" plugin add "$name" 2>&1)"; then
      bad="$bad
$name: add failed:
$out"
      continue
    fi
    out="$("$NK" doctor --plugin "$name" 2>&1 || true)"
    if printf '%s\n' "$out" | grep -qE '^fail '; then
      bad="$bad
$name: doctor fail row:
$(printf '%s\n' "$out" | grep -E '^fail ')"
    fi
    if ! out="$("$NK" plugin remove "$name" 2>&1)"; then
      bad="$bad
$name: remove failed:
$out"
      continue
    fi
    # requires_plugins pulled others in; remove them too so the next plugin
    # starts clean, and so a link they left is counted against them.
    local left
    left="$(sed -n 's/^plugins = \[\(.*\)\]/\1/p' "$HOME/.config/nekoshell/nekoshell.toml" | tr -d '" ' | tr ',' ' ')"
    local p
    for p in $left; do "$NK" plugin remove "$p" >/dev/null 2>&1 || true; done
    out="$(links_into_checkout)"
    if [[ -n "$out" ]]; then
      bad="$bad
$name: links left after remove:
$out"
      rm -f $(printf '%s\n' "$out" | sed 's/ -> .*//')
    fi
  done
  if [[ -n "$bad" ]]; then echo "plugin sweep:$bad" >&2; false; fi
}
