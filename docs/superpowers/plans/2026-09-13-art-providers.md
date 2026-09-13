# Art Providers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the greet plugin into an engine that draws a sprite from any enabled *art provider* plugin, move the Pokémon into a `pokemon` plugin that every profile enables, and add `anime`, `minecraft` and `colorscripts` providers.

**Architecture:** A plugin is an art provider when it ships an executable `greet-art` that prints a caption line and then a sprite. `plugins/greet/bin/nekoshell-greet` discovers providers among the enabled plugins, picks one by `ART` in `greet.conf` (equal odds, or weights), pipes its sprite into fastfetch, and falls back to stats alone. Providers fetch their sprite packs into `~/.local/share/<name>` in their install hook, pinned, and pick a file themselves.

**Tech Stack:** bash 3.2, zsh, fastfetch, bats 1.14 with the fakes under `tests/fakes/`, shellcheck + shfmt via `scripts/lint.sh`.

**Spec:** `docs/superpowers/specs/2026-09-13-art-providers-and-plugins-design.md`, section 1.

## Global Constraints

- bash 3.2 (no `${var,,}`, no associative arrays, no `mapfile`), `set -uo pipefail` in bin scripts, `shellcheck -x` clean, `shfmt -i 2 -ci -bn` clean.
- Every plugin: the nine `plugin.toml` keys (`name summary requires casks taps requires_plugins terminals conflicts tags`), README with the five sections `## What it does`, `## Installs`, `## Files`, `## After install`, `## Remove`, a page under `docs/plugins/`, tests in `tests/plugins/<name>.bats` (enforced by `tests/core/repo.bats`).
- The greeting never fails a fresh shell: every problem exits 0 quietly; the doctor's greet budget is 150 ms.
- Install hooks warn and carry on when offline; they never abort `plugin add`.
- Every write in a hook goes through `run` (dry-run aware) except renders and the recorded config, as the core does.
- Commit messages: conventional, lower-case, subject ≤ 72 chars, blank second line, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. `make hooks` is installed; the pre-commit hook runs lint.
- Branch: `feat/art-providers` from `main`. One PR at the end.

---

### Task 1: Provider fixtures and the engine's provider selection

**Files:**

- Create: `tests/fixtures/plugins/fakeart/plugin.toml`, `tests/fixtures/plugins/fakeart/greet-art`, `tests/fixtures/plugins/fakeart2/plugin.toml`, `tests/fixtures/plugins/fakeart2/greet-art`
- Modify: `plugins/greet/bin/nekoshell-greet` (the whole art half)
- Modify: `tests/plugins/greet.bats` (setup, the pokemon tests)

**Interfaces:**

- Produces: the provider contract. The engine runs `$NEKOSHELL_PLUGINS_DIR/<name>/greet-art` with `PLUGIN_NAME`, `PLUGIN_DIR` set to that plugin, `NEKOSHELL_CONFIG`, `NEKOSHELL_CACHE`, `NEKOSHELL_SEED` (when set) and every `greet.conf` key exported. Stdout line 1 is the caption, the rest the sprite; exit non-zero with no output means "nothing to draw".
- Produces: `greet.conf` keys `ART` (`auto` or `name:weight,name:weight`), `SPRITE_SHARE` (old `POKEMON_SHARE` still read), `IMAGE_WIDTH`, `IMAGE_HEIGHT`.
- Produces: `NEKOSHELL_GREET_ART=NAME` forces a provider (Task 2 wires `--art`).

- [ ] **Step 1: Fixture providers**

`tests/fixtures/plugins/fakeart/plugin.toml`:

```toml
name = "fakeart"
summary = "A fixture art provider"
requires = []
casks = []
taps = []
requires_plugins = ["greet"]
terminals = ["any"]
conflicts = []
tags = ["look"]
```

`tests/fixtures/plugins/fakeart/greet-art` (chmod +x):

```bash
#!/usr/bin/env bash
# Fixture provider: a caption and three lines, or nothing at all when
# FAKEART_FAIL=1, the way a provider whose pack never arrived behaves.
[[ "${FAKEART_FAIL:-}" == 1 ]] && exit 1
echo "Fake Art · one"
printf '▄▄▄\n███\n▀▀▀\n'
```

`fakeart2` is the same with `name = "fakeart2"`, the caption `Fake Art · two` and `FAKEART2_FAIL`.

- [ ] **Step 2: greet.bats setup builds a plugins dir of symlinks**

Replace the `setup()` in `tests/plugins/greet.bats` with one that points `NEKOSHELL_PLUGINS_DIR` at a directory holding the real greet plugin and the fixtures, so the engine and the doctor both find providers there:

```bash
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset CLAUDECODE TMUX NEKOSHELL_PANEL SSH_CONNECTION NEKOSHELL_NO_GREET NEKOSHELL_GREET_SSH NEKOSHELL_GREET_MODE NEKOSHELL_GREET_ART FAKEART_FAIL FAKEART2_FAIL
  unset NEKOSHELL_ROOT
  # The engine looks for providers among the enabled plugins under
  # NEKOSHELL_PLUGINS_DIR. A directory of links carries the real greet plugin
  # next to the two fixture providers.
  export NEKOSHELL_PLUGINS_DIR="$HOME/plugins"
  mkdir -p "$NEKOSHELL_PLUGINS_DIR"
  ln -s "$REPO_ROOT/plugins/greet" "$NEKOSHELL_PLUGINS_DIR/greet"
  ln -s "$REPO_ROOT/tests/fixtures/plugins/fakeart" "$NEKOSHELL_PLUGINS_DIR/fakeart"
  ln -s "$REPO_ROOT/tests/fixtures/plugins/fakeart2" "$NEKOSHELL_PLUGINS_DIR/fakeart2"
  mkdir -p "$HOME/.config/nekoshell/art" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = ["greet", "fakeart"]\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/greet"
}
```

Add a helper next to `set_flavour`:

```bash
# set_plugins LIST: rewrite the enabled list, e.g. set_plugins '"greet", "fakeart", "fakeart2"'.
set_plugins() {
  sed "s/^plugins = .*/plugins = [$1]/" "$HOME/.config/nekoshell/nekoshell.toml" > "$HOME/t.toml"
  mv "$HOME/t.toml" "$HOME/.config/nekoshell/nekoshell.toml"
}
```

- [ ] **Step 3: Failing tests for selection**

Replace the tests "the pokemon path pipes the sprite into fastfetch and caches the name", "shiny odds of 1 always passes -s", "a terminal that cannot draw images falls back to the pokemon", "falls back to the pokemon when the art pack is empty" and "NEKOSHELL_GREET_MODE forces either branch" with:

```bash
@test "a provider's sprite goes into fastfetch and its caption into the cache" {
  run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--file-raw - stdin=3"
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · one" ]
}

@test "ART=auto picks among the enabled providers with equal odds" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  local seen=""
  for seed in 1 2 3 4 5 6 7 8; do
    NEKOSHELL_SEED=$seed NEKOSHELL_GREET_MODE=text greet >/dev/null
    seen="$seen $(cat "$HOME/.cache/nekoshell/art-name")"
  done
  assert_contains "$seen" "Fake Art · one"
  assert_contains "$seen" "Fake Art · two"
}

@test "ART weights: a zero weight never draws, a missing name is skipped" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  printf 'ART="fakeart:0,fakeart2:5,nothere:9"\n' > "$HOME/.config/nekoshell/greet.conf"
  for seed in 1 2 3 4 5; do
    NEKOSHELL_SEED=$seed NEKOSHELL_GREET_MODE=text greet >/dev/null
    [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
  done
}

@test "a provider that draws nothing gives way to the stats alone" {
  FAKEART_FAIL=1 run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--logo none"
  assert_not_contains "$output" "--file-raw"
  [ ! -s "$HOME/.cache/nekoshell/art-name" ]
}

@test "no provider enabled: the stats alone" {
  set_plugins '"greet"'
  run greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "--logo none"
}

@test "NEKOSHELL_GREET_ART forces a provider" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  NEKOSHELL_GREET_ART=fakeart2 run greet
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
}

@test "a terminal that cannot draw images falls back to the sprite" {
  set_terminal bare
  NEKOSHELL_SEED=99 run greet
  assert_contains "$output" "--file-raw - stdin=3"
}

@test "the old POKEMON_SHARE key still sets the sprite share" {
  printf 'POKEMON_SHARE=0\n' > "$HOME/.config/nekoshell/greet.conf"
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  set_terminal fake
  run greet
  assert_contains "$output" "--kitty"
}

@test "NEKOSHELL_GREET_MODE forces either branch" {
  cp "$P/art/neko.png" "$HOME/.config/nekoshell/art/"
  set_terminal fake
  NEKOSHELL_GREET_MODE=text run greet
  assert_contains "$output" "--file-raw"
  NEKOSHELL_GREET_MODE=image run greet
  assert_contains "$output" "--kitty"
}

@test "greet.conf keys reach the provider" {
  printf 'FAKEART_FAIL=1\n' > "$HOME/.config/nekoshell/greet.conf"
  run greet
  assert_contains "$output" "--logo none"
}
```

(`set_terminal fake` is the fixture adapter whose capabilities include `images`; `bare` has none. Both already exist under `tests/fixtures/terminals`.)

- [ ] **Step 4: Run to verify they fail**

Run: `bats tests/plugins/greet.bats`
Expected: the new tests fail (no `--logo none`, captions still `Pikachu`).

- [ ] **Step 5: The engine**

In `plugins/greet/bin/nekoshell-greet`, keep everything up to and including the `NEKOSHELL_ROOT` resolution and the `NEKOSHELL_CONFIG`/`NEKOSHELL_CACHE` lines. Replace the defaults block, `pokemon_facts`, `show_pokemon` and the final roll with:

```bash
NEKOSHELL_PLUGINS_DIR="${NEKOSHELL_PLUGINS_DIR:-$NEKOSHELL_ROOT/plugins}"
export NEKOSHELL_CONFIG NEKOSHELL_CACHE NEKOSHELL_PLUGINS_DIR

# greet.conf: the engine's own keys, and any a provider reads. It is sourced
# with everything exported, so a provider (a separate process) sees the same
# keys without parsing the file again.
ART="auto"
SPRITE_SHARE=""
POKEMON_SHARE=""
IMAGE_WIDTH=28
IMAGE_HEIGHT=14
set -a
if [[ -r "$NEKOSHELL_CONFIG/greet.conf" ]]; then
  # shellcheck source=/dev/null
  source "$NEKOSHELL_CONFIG/greet.conf"
fi
set +a
# SPRITE_SHARE used to be POKEMON_SHARE, back when the Pokémon was the only sprite.
[[ -n "$SPRITE_SHARE" ]] || SPRITE_SHARE="${POKEMON_SHARE:-70}"

[[ -n "${NEKOSHELL_SEED:-}" ]] && RANDOM="$NEKOSHELL_SEED"
mkdir -p "$NEKOSHELL_CACHE"
ff_config="$HOME/.config/fastfetch/config.jsonc"
```

Keep `image_flag`, `pick_image` and `show_image` as they are. Add after `pick_image`:

```bash
# enabled_plugins: the names on the plugins line of nekoshell.toml, in order.
# Read with sed rather than the core config library, which would cost the
# greeting a few more sourced files on every shell.
enabled_plugins() {
  local toml="$NEKOSHELL_CONFIG/nekoshell.toml" line
  [[ -r "$toml" ]] || return 0
  line="$(sed -n 's/^plugins[[:space:]]*=[[:space:]]*\[\(.*\)\].*/\1/p' "$toml" | head -1)"
  printf '%s\n' "$line" | tr ',' '\n' | tr -d '" ' | sed '/^$/d'
  return 0
}

# providers: the enabled plugins that ship an executable greet-art, in the
# order they were enabled. That file is the whole of the provider contract:
# the caption on the first line, the sprite after it, silence and a non-zero
# status when there is nothing to draw.
providers() {
  local p
  for p in $(enabled_plugins); do
    [[ -x "$NEKOSHELL_PLUGINS_DIR/$p/greet-art" ]] && printf '%s\n' "$p"
  done
  return 0
}

# pick_provider: one provider name by ART, or nothing when none applies.
# "auto" gives every enabled provider the same odds. A list such as
# "pokemon:70,anime:30" weights them; a name without a weight counts 1, a
# name that is not an enabled provider is dropped, and a weight of 0 never
# draws.
pick_provider() {
  local names=() weights=() total=0 entry name w p roll acc i avail
  if [[ -z "$ART" || "$ART" == "auto" ]]; then
    for p in $(providers); do
      names+=("$p")
      weights+=(1)
      total=$((total + 1))
    done
  else
    avail=" $(providers | tr '\n' ' ')"
    for entry in ${ART//,/ }; do
      name="${entry%%:*}"
      w="${entry#*:}"
      [[ "$w" == "$entry" ]] && w=1
      [[ "$w" =~ ^[0-9]+$ ]] || w=1
      [[ "$avail" == *" $name "* ]] || continue
      ((w > 0)) || continue
      names+=("$name")
      weights+=("$w")
      total=$((total + w))
    done
  fi
  [[ ${#names[@]} -gt 0 ]] || return 0
  roll=$((RANDOM % total))
  acc=0
  for i in "${!names[@]}"; do
    acc=$((acc + weights[i]))
    if ((roll < acc)); then
      printf '%s\n' "${names[i]}"
      return 0
    fi
  done
}

# show_sprite NAME: run NAME's greet-art and hand fastfetch the sprite. The
# caption goes to the cache for the "Art" row. A provider that prints nothing
# usable fails this, and the caller shows the stats alone.
show_sprite() {
  local name="$1" out
  out="$(PLUGIN_NAME="$name" PLUGIN_DIR="$NEKOSHELL_PLUGINS_DIR/$name" \
    "$NEKOSHELL_PLUGINS_DIR/$name/greet-art" 2>/dev/null)" || return 1
  [[ "$out" == *$'\n'* ]] || return 1
  printf '%s\n' "${out%%$'\n'*}" >"$NEKOSHELL_CACHE/art-name"
  printf '%s\n' "${out#*$'\n'}" | fastfetch --config "$ff_config" --file-raw -
}

# show_stats: the machine stats with no picture, which is still a greeting.
show_stats() {
  : >"$NEKOSHELL_CACHE/art-name"
  fastfetch --config "$ff_config" --logo none </dev/null
}
```

And the tail of the script:

```bash
# The roll is taken whatever the mode, so a forced greeting and an automatic
# one draw the same sprite from the same seed.
roll=$((RANDOM % 100))
img=""
flag=""
mode="${NEKOSHELL_GREET_MODE:-auto}"
[[ -n "${NEKOSHELL_GREET_ART:-}" ]] && mode=text
case "$mode" in
  text) ;;
  image)
    flag="$(image_flag)"
    [[ -n "$flag" ]] && img="$(pick_image)"
    ;;
  *) if ((roll >= SPRITE_SHARE)); then
    flag="$(image_flag)"
    [[ -n "$flag" ]] && img="$(pick_image)"
  fi ;;
esac

if [[ -n "$img" ]]; then
  show_image "$img" "$flag"
else
  provider="${NEKOSHELL_GREET_ART:-}"
  [[ -n "$provider" ]] || provider="$(pick_provider)"
  if [[ -z "$provider" ]] || ! show_sprite "$provider"; then
    show_stats
  fi
fi
```

- [ ] **Step 6: Run the greet suite**

Run: `bats tests/plugins/greet.bats`
Expected: the selection tests pass; the tests that still name pokemon-colorscripts (clone, doctor) fail — Task 2 and Task 3 handle those.

- [ ] **Step 7: Commit**

```bash
git add tests/fixtures/plugins/fakeart tests/fixtures/plugins/fakeart2 plugins/greet/bin/nekoshell-greet tests/plugins/greet.bats
git commit -m "feat(greet): draw the sprite from an enabled art provider plugin"
```

---

### Task 2: greet's config, command, doctor, install hook and docs

**Files:**

- Modify: `plugins/greet/files/copy/.config/nekoshell/greet.conf`, `plugins/greet/cmd/greet.sh`, `plugins/greet/doctor.sh`, `plugins/greet/README.md`, `docs/plugins/greet.md`
- Delete: `plugins/greet/install.sh`, `plugins/greet/data/pokemon.tsv`, `plugins/greet/scripts/gen-pokemon-data.py` (they move to `plugins/pokemon` in Task 3: use `git mv`)
- Test: `tests/plugins/greet.bats`

**Interfaces:**

- Consumes: `NEKOSHELL_GREET_ART` from Task 1.
- Produces: `nekoshell greet --art NAME`; doctor rows `art: NAME` and the warn `art` row.

- [ ] **Step 1: Failing tests**

Replace "doctor reports fastfetch, pokemon-colorscripts and the greet budget" and "add clones pokemon-colorscripts …" (all four clone tests) with:

```bash
@test "add installs fastfetch and clones nothing" {
  run "$NK" plugin add greet
  [ "$status" -eq 0 ]
  assert_contains "$output" "brew install fastfetch"
  assert_not_contains "$output" "git clone"
}

@test "doctor reports one row per enabled provider and the greet budget" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  run "$NK" doctor --plugin greet
  assert_matches "$output" 'ok +tool: fastfetch'
  assert_matches "$output" 'ok +art: fakeart +draws'
  assert_matches "$output" 'ok +art: fakeart2 +draws'
  assert_matches "$output" '(ok|warn) +greet time'
  FAKEART_FAIL=1 run "$NK" doctor --plugin greet
  assert_matches "$output" 'fail +art: fakeart +nothing to draw'
}

@test "doctor warns when no provider is enabled" {
  set_plugins '"greet"'
  run "$NK" doctor --plugin greet
  assert_matches "$output" 'warn +art +no art provider enabled \(run: nekoshell plugin add pokemon\)'
}

@test "nekoshell greet --art forces a provider and refuses one that is not enabled" {
  set_plugins '"greet", "fakeart", "fakeart2"'
  run script -q /dev/null "$NK" greet --art fakeart2 < /dev/null
  [ "$(cat "$HOME/.cache/nekoshell/art-name")" = "Fake Art · two" ]
  run "$NK" greet --art nothere
  [ "$status" -eq 1 ]
  assert_contains "$output" "nothere is not an enabled art provider"
}
```

Also drop the two pokemon data tests ("pokemon.tsv has the header…", "pokemon_facts formats…"): Task 3 re-homes them.

- [ ] **Step 2: Run to verify they fail**

Run: `bats tests/plugins/greet.bats`

- [ ] **Step 3: greet.conf**

```bash
# nekoshell greeting settings (sourced by bash; keep KEY=VALUE).
ART=auto           # which art provider draws: auto (equal odds among the enabled
                   # ones) or weights, e.g. "pokemon:70,anime:30"
SPRITE_SHARE=70    # percent of launches that show a sprite; the rest use your art
                   # pack, in a terminal that can draw images
IMAGE_WIDTH=28     # art pack image size in terminal cells
IMAGE_HEIGHT=14
# Provider settings live here too, prefixed with the provider's name, e.g.
# POKEMON_SHINY_ODDS=128 or ANIME_ONLY="miku naruto"; see each provider's page.
```

- [ ] **Step 4: cmd/greet.sh**

Add `--art NAME` to the usage and the parser:

```bash
      --art)
        [[ -n "${2:-}" ]] || {
          usage_greet >&2
          return 2
        }
        if ! plugin_enabled "$2" || [[ ! -x "$(plugin_dir "$2")/greet-art" ]]; then
          log_fail "$2 is not an enabled art provider (nekoshell plugin list)"
          return 1
        fi
        export NEKOSHELL_GREET_ART="$2"
        mode="text"
        shift 2
        ;;
```

Usage text:

```text
usage: nekoshell greet [--image|--text|--art NAME]

  --image      use the art pack, if this terminal can draw images
  --text       use a sprite from an enabled art provider, whatever the terminal
  --art NAME   use that provider's sprite (pokemon, anime, ...)

With none of them, the greeting rolls for it: SPRITE_SHARE in
~/.config/nekoshell/greet.conf is the percentage that goes to a sprite, and
ART says which providers draw.
```

- [ ] **Step 5: doctor.sh**

Replace the pokemon-colorscripts block with:

```bash
# One row per enabled art provider, asked to draw rather than just to exist:
# a pack that never arrived answers `-x` and nothing else.
_greet_any=0
for _greet_p in $(plugin_enabled_all); do
  _greet_art="$(plugin_dir "$_greet_p")/greet-art"
  [[ -x "$_greet_art" ]] || continue
  _greet_any=1
  if PLUGIN_NAME="$_greet_p" PLUGIN_DIR="$(plugin_dir "$_greet_p")" "$_greet_art" >/dev/null 2>&1; then
    report ok "art: $_greet_p" "draws"
  else
    report fail "art: $_greet_p" "nothing to draw (nekoshell plugin add $_greet_p)"
  fi
done
[[ "$_greet_any" == 1 ]] || report warn "art" "no art provider enabled (run: nekoshell plugin add pokemon)"
```

- [ ] **Step 6: Remove the install hook, move the data**

```bash
git rm plugins/greet/install.sh
mkdir -p plugins/pokemon/data plugins/pokemon/scripts
git mv plugins/greet/data/pokemon.tsv plugins/pokemon/data/pokemon.tsv
git mv plugins/greet/scripts/gen-pokemon-data.py plugins/pokemon/scripts/gen-pokemon-data.py
```

(`plugins/greet/scripts/gen-sample-art.py` stays.)

- [ ] **Step 7: README and docs page**

`plugins/greet/README.md`: "What it does" describes the engine (a sprite from an enabled art provider, or a picture from the art pack, next to fastfetch's stats; `ART` and `SPRITE_SHARE`; `--art`); "Installs" is fastfetch only; "Files" drops the pokemon-colorscripts lines; "After install" says "Enable an art provider: `nekoshell plugin add pokemon` (every profile does). `nekoshell art sample` for the shipped pictures."; "Remove" drops the checkout sentence. Keep the copyright note.

`docs/plugins/greet.md`: the same shape as today with a new "Art providers" section:

```markdown
## Art providers

The sprite comes from an enabled plugin that ships a `greet-art` program: `pokemon` (in every profile), `anime`, `minecraft` and `colorscripts`. `ART` in `greet.conf` picks among them: `auto` gives each the same odds; `pokemon:70,anime:30` weights them; a name that is not enabled is skipped. `nekoshell greet --art anime` forces one. With no provider enabled the stats print on their own, and the doctor says so.
```

Update the Files table (`ART`, `SPRITE_SHARE`; remove the pokemon rows) and the commands table (`--art`).

- [ ] **Step 8: Run, lint, commit**

Run: `bats tests/plugins/greet.bats && scripts/lint.sh`
Expected: all pass (the two pokemon data tests are gone for now).

```bash
git add -A plugins/greet plugins/pokemon docs/plugins/greet.md tests/plugins/greet.bats
git commit -m "feat(greet): ART and SPRITE_SHARE in greet.conf, --art, provider doctor rows"
```

---

### Task 3: The pokemon provider

**Files:**

- Create: `plugins/pokemon/plugin.toml`, `plugins/pokemon/greet-art`, `plugins/pokemon/install.sh`, `plugins/pokemon/doctor.sh`, `plugins/pokemon/README.md`, `docs/plugins/pokemon.md`
- Modify: `profiles/minimal.txt`, `profiles/dev.txt`, `profiles/full.txt`, `THIRD_PARTY.md`
- Test: `tests/plugins/pokemon.bats`

**Interfaces:**

- Consumes: the provider contract (Task 1). Reads `POKEMON_SHINY_ODDS` (falls back to the old `SHINY_ODDS`, default 128) and `POKEMON_GENERATIONS` (old `GENERATIONS`, default all).
- Produces: `pokemon-colorscripts` on `~/.local/bin`, `~/.local/share/pokemon-colorscripts` at the pin.

- [ ] **Step 1: Failing tests**

`tests/plugins/pokemon.bats`:

```bash
#!/usr/bin/env bats
# The pokemon art provider: pokemon-colorscripts, pinned, and a greet-art that
# captions the sprite with the Pokédex facts.
load ../helpers
setup() {
  setup_tmp_home
  export PATH="$REPO_ROOT/tests/fakes:$PATH"
  export NEKOSHELL_TERMINALS_DIR="$REPO_ROOT/tests/fixtures/terminals"
  export FAKE_BREW_INSTALLED=""
  unset FAKE_GIT_HAS_COMMIT FAKE_GIT_FAIL_FETCH FAKE_GIT_NOT_REPO NEKOSHELL_SEED
  mkdir -p "$HOME/.config/nekoshell" "$HOME/.cache/nekoshell"
  printf 'root = "%s"\nterminal = "fake"\ntheme = "mocha"\ntheme_resolved = "mocha"\nplugins = []\n' "$REPO_ROOT" > "$HOME/.config/nekoshell/nekoshell.toml"
  NK="$REPO_ROOT/bin/nekoshell"
  P="$REPO_ROOT/plugins/pokemon"
  export PLUGIN_DIR="$P" PLUGIN_NAME=pokemon
}
teardown() { teardown_tmp_home; }

@test "plugin.toml is complete, requires greet, and the README has its five sections" {
  for k in name summary requires casks taps requires_plugins terminals conflicts tags; do
    grep -q "^$k *=" "$P/plugin.toml"
  done
  grep -q '^requires_plugins = \["greet"\]' "$P/plugin.toml"
  for s in "## What it does" "## Installs" "## Files" "## After install" "## Remove"; do
    grep -qF "$s" "$P/README.md"
  done
  [ -x "$P/greet-art" ]
}

@test "add enables greet first, clones pokemon-colorscripts at the pinned commit and links it onto PATH" {
  run "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_contains "$output" "pokemon needs greet; adding it first"
  assert_contains "$output" "git clone --quiet https://gitlab.com/phoneybadger/pokemon-colorscripts.git $HOME/.local/share/pokemon-colorscripts"
  assert_contains "$output" "checkout --quiet 5802ff67520be2ff6117a0abc78a08501f6252ad"
  [ -L "$HOME/.local/bin/pokemon-colorscripts" ]
  grep -q '"greet", "pokemon"' "$HOME/.config/nekoshell/nekoshell.toml"
}

@test "a second add does not clone again" {
  "$NK" plugin add pokemon >/dev/null
  run "$NK" plugin add pokemon
  assert_not_contains "$output" "git clone"
  assert_contains "$output" "git -C $HOME/.local/share/pokemon-colorscripts fetch"
}

@test "a checkout that already holds the pinned commit is not fetched" {
  "$NK" plugin add pokemon >/dev/null
  FAKE_GIT_HAS_COMMIT=1 run "$NK" plugin add pokemon
  assert_not_contains "$output" "fetch"
  assert_contains "$output" "checkout --quiet 5802ff6"
}

@test "a fetch that fails warns and the add still succeeds" {
  "$NK" plugin add pokemon >/dev/null
  FAKE_GIT_FAIL_FETCH=1 run "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_contains "$output" "could not fetch pokemon-colorscripts; keeping what is there"
}

@test "a pokemon directory that is not a checkout warns and the add still succeeds" {
  mkdir -p "$HOME/.local/share/pokemon-colorscripts"
  FAKE_GIT_NOT_REPO=1 run "$NK" plugin add pokemon
  [ "$status" -eq 0 ]
  assert_contains "$output" "could not check out pokemon-colorscripts"
  assert_contains "$output" "pokemon-colorscripts.py is missing"
}

@test "greet-art prints the facts caption and then the sprite" {
  run "$P/greet-art"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1" ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "greet-art is silent and non-zero without pokemon-colorscripts" {
  PATH="/usr/bin:/bin" run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "shiny odds of 1 always passes -s, and the old SHINY_ODDS key still works" {
  POKEMON_SHINY_ODDS=1 run "$P/greet-art"
  [ "${lines[0]}" = "Pikachu · #025 · Electric · Gen 1 ✦ shiny" ]
  SHINY_ODDS=1 run "$P/greet-art"
  assert_contains "${lines[0]}" "✦ shiny"
}

@test "doctor reports pokemon-colorscripts" {
  "$NK" plugin add pokemon >/dev/null
  run "$NK" doctor --plugin pokemon
  assert_matches "$output" 'ok +pokemon-colorscripts'
  PATH="/usr/bin:/bin:$REPO_ROOT/tests/fakes-none" run "$NK" doctor --plugin pokemon
  assert_matches "$output" 'fail +pokemon-colorscripts +missing or broken'
}

@test "pokemon.tsv has the header and well-known rows" {
  head -1 "$P/data/pokemon.tsv" | grep -q $'^name\tid\ttypes\tgeneration$'
  grep -q $'^pikachu\t25\tElectric\t1$' "$P/data/pokemon.tsv"
  grep -q $'^bulbasaur\t1\tGrass/Poison\t1$' "$P/data/pokemon.tsv"
}

@test "every profile enables pokemon right after greet" {
  for p in minimal dev full; do
    grep -A1 '^greet$' "$REPO_ROOT/profiles/$p.txt" | grep -qx pokemon
  done
}
```

(Check the exact tsv header and row format against the file before committing; the current greet tests carry the same assertions. The doctor "missing" case: keep the `PATH` override the current greet test uses.)

- [ ] **Step 2: Run to verify they fail**

Run: `bats tests/plugins/pokemon.bats`

- [ ] **Step 3: plugin.toml, install.sh, greet-art, doctor.sh**

`plugin.toml`:

```toml
name = "pokemon"
summary = "A random Pokémon sprite in the greeting, captioned with its number, type and generation"
requires = []
casks = []
taps = []
requires_plugins = ["greet"]
terminals = ["any"]
conflicts = []
tags = ["look"]
```

`install.sh`: the former `plugins/greet/install.sh` verbatim, with the header comment reading "pokemon install: fetch pokemon-colorscripts, pinned."

`greet-art` (chmod +x):

```bash
#!/usr/bin/env bash
# pokemon greet-art: the caption line, then the sprite, from pokemon-colorscripts.
# Silent and non-zero when there is nothing to draw: the greeting then shows
# the stats alone. Keys from greet.conf: POKEMON_SHINY_ODDS (1 in N shiny,
# 128), POKEMON_GENERATIONS ("1-3" or "1,4", empty for all). The older
# unprefixed names still work, for a greet.conf copied before this plugin.
set -uo pipefail
command -v pokemon-colorscripts >/dev/null 2>&1 || exit 1
[[ -n "${NEKOSHELL_SEED:-}" ]] && RANDOM="$NEKOSHELL_SEED"

tsv="${PLUGIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}/data/pokemon.tsv"
shiny_odds="${POKEMON_SHINY_ODDS:-${SHINY_ODDS:-128}}"
generations="${POKEMON_GENERATIONS:-${GENERATIONS:-}}"

# facts NAME: "Pikachu · #025 · Electric · Gen 1", or the capitalised name alone.
facts() {
  local name="$1" cap
  cap="$(printf '%s' "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
  if [[ -r "$tsv" ]]; then
    awk -F'\t' -v n="$name" -v cap="$cap" '$1==n {printf "%s · #%03d · %s · Gen %s\n", cap, $2, $3, $4; found=1} END {if (!found) print cap}' "$tsv"
  else
    printf '%s\n' "$cap"
  fi
}

args=(-r)
[[ -n "$generations" ]] && args+=("$generations")
shiny=""
if ((shiny_odds > 0)) && ((RANDOM % shiny_odds == 0)); then
  args+=(-s)
  shiny=" ✦ shiny"
fi
out="$(pokemon-colorscripts "${args[@]}" 2>/dev/null)" || exit 1
[[ "$out" == *$'\n'* ]] || exit 1
name="${out%%$'\n'*}"
printf '%s%s\n' "$(facts "$name")" "$shiny"
printf '%s\n' "${out#*$'\n'}"
```

`doctor.sh`: the pokemon-colorscripts block from the old greet doctor, message `missing or broken (nekoshell plugin add pokemon)`.

- [ ] **Step 4: Profiles, README, docs, THIRD_PARTY**

`profiles/minimal.txt` becomes `modern-cli`, `greet`, `pokemon`; `dev.txt` and `full.txt` get `pokemon` after `greet` too.

`plugins/pokemon/README.md` (five sections): what it does (a random Pokémon of the enabled generations, shiny 1 in N, captioned with the Pokédex facts, drawn by the greet plugin), installs (pokemon-colorscripts, not in Homebrew, cloned at the pinned commit into `~/.local/share/pokemon-colorscripts`, linked at `~/.local/bin/pokemon-colorscripts`), files (none of yours; the keys in `greet.conf`), after install (nothing), remove (`nekoshell plugin remove pokemon`; the checkout stays; `rm -rf ~/.local/share/pokemon-colorscripts ~/.local/bin/pokemon-colorscripts` to drop it). Keep the copyright note about sprites.

`docs/plugins/pokemon.md`: the same shape as `docs/plugins/omz.md` (What you get, Using it, Files, Theme, Turning it off), with the two keys.

`THIRD_PARTY.md`: the `pokemon.tsv` row's path becomes `plugins/pokemon/data/pokemon.tsv`, generated by `plugins/pokemon/scripts/gen-pokemon-data.py`; add a "Fetched at install time" row for pokemon-colorscripts (`5802ff67520be2ff6117a0abc78a08501f6252ad`, pinned in `plugins/pokemon/install.sh`, into `~/.local/share/pokemon-colorscripts`, MIT).

- [ ] **Step 5: Run, lint, commit**

Run: `bats tests/plugins/pokemon.bats tests/plugins/greet.bats tests/core/repo.bats tests/core/install.bats && scripts/lint.sh`

```bash
git add -A plugins/pokemon profiles THIRD_PARTY.md docs/plugins/pokemon.md tests/plugins/pokemon.bats
git commit -m "feat(pokemon): the pokémon greeting as an art provider, in every profile"
```

---

### Task 4: The anime provider

**Files:**

- Create: `plugins/anime/plugin.toml`, `plugins/anime/install.sh`, `plugins/anime/greet-art`, `plugins/anime/doctor.sh`, `plugins/anime/README.md`, `docs/plugins/anime.md`
- Modify: `tests/fakes/curl` (a `FAKE_CURL_SOURCE` switch), `THIRD_PARTY.md`
- Test: `tests/plugins/anime.bats`

**Interfaces:**

- Consumes: the provider contract. Reads `ANIME_ONLY` (words; only names containing one are drawn) and `ANIME_SKIP` (words never drawn; default `fuck`, one file in the pack is named that way).
- Produces: `~/.local/share/anime-colorscripts/{colorscripts/*.txt,charalist.txt,.nekoshell-version}`.

- [ ] **Step 1: The fake curl learns to deliver a file**

`tests/fakes/curl`: after finding `dest`, `if [[ -n "${FAKE_CURL_SOURCE:-}" ]]; then cp "$FAKE_CURL_SOURCE" "$dest"; else printf '# fake iTerm2 shell integration\n' >"$dest"; fi`. `FAKE_CURL_FAIL=1` exits 22 before writing anything.

- [ ] **Step 2: Failing tests**

`tests/plugins/anime.bats` with the same setup as pokemon.bats (`P="$REPO_ROOT/plugins/anime"`), plus a tarball built in setup:

```bash
  # A tarball with the release's layout: ./anime-colorscripts/colorscripts/*.txt.
  mkdir -p "$HOME/src/anime-colorscripts/colorscripts"
  printf '2997-hatsune-miku\n1-naruto-uzumaki\n9-fuck-you\n' > "$HOME/src/anime-colorscripts/charalist.txt"
  for n in 2997-hatsune-miku 1-naruto-uzumaki 9-fuck-you; do printf 'ART %s\nline2\n' "$n" > "$HOME/src/anime-colorscripts/colorscripts/$n.txt"; done
  (cd "$HOME/src" && tar czf "$HOME/anime.tar.gz" ./anime-colorscripts)
  export FAKE_CURL_SOURCE="$HOME/anime.tar.gz"
  export NEKOSHELL_ANIME_SHA256="$(shasum -a 256 "$HOME/anime.tar.gz" | cut -d' ' -f1)"
  ANIME_DIR="$HOME/.local/share/anime-colorscripts"
```

Tests:

```bash
@test "plugin.toml is complete, requires greet, and the README has its five sections" { ...as pokemon... }

@test "add downloads the pinned release, checks it and unpacks the sprites" {
  run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "curl -fsSL -o"
  assert_contains "$output" "releases/download/v1.1.3/anime-colorscripts.tar.gz"
  [ -f "$ANIME_DIR/colorscripts/2997-hatsune-miku.txt" ]
  [ "$(cat "$ANIME_DIR/.nekoshell-version")" = "v1.1.3" ]
}

@test "a second add does not download again" {
  "$NK" plugin add anime >/dev/null
  run "$NK" plugin add anime
  assert_not_contains "$output" "curl"
  assert_contains "$output" "already here"
}

@test "a checksum mismatch keeps what is there and still succeeds" {
  NEKOSHELL_ANIME_SHA256="0000000000000000000000000000000000000000000000000000000000000000" run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "does not match the recorded checksum"
  [ ! -d "$ANIME_DIR/colorscripts" ]
}

@test "a download that fails warns and still succeeds" {
  FAKE_CURL_FAIL=1 run "$NK" plugin add anime
  [ "$status" -eq 0 ]
  assert_contains "$output" "could not download anime-colorscripts"
}

@test "greet-art captions the file name and prints the sprite" {
  "$NK" plugin add anime >/dev/null
  ANIME_ONLY=miku run "$P/greet-art"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Hatsune Miku" ]
  [ "${lines[1]}" = "ART 2997-hatsune-miku" ]
}

@test "ANIME_SKIP words are never drawn, and the default skips the rude one" {
  "$NK" plugin add anime >/dev/null
  local seen=""
  for seed in 1 2 3 4 5 6 7 8 9 10; do
    seen="$seen $(NEKOSHELL_SEED=$seed "$P/greet-art" | head -1)"
  done
  assert_not_contains "$seen" "Fuck"
  ANIME_SKIP="miku naruto" run "$P/greet-art"
  [ "$status" -eq 1 ]
}

@test "greet-art is silent and non-zero before the pack is there" {
  run "$P/greet-art"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "doctor reports the pack" {
  "$NK" plugin add anime >/dev/null
  run "$NK" doctor --plugin anime
  assert_matches "$output" 'ok +anime-colorscripts +v1\.1\.3, 3 sprites'
  rm -rf "$ANIME_DIR"
  run "$NK" doctor --plugin anime
  assert_matches "$output" 'fail +anime-colorscripts +missing \(nekoshell plugin add anime\)'
}
```

- [ ] **Step 3: Run to verify they fail**

- [ ] **Step 4: Implementation**

`plugin.toml`: name `anime`, summary "A random anime character sprite in the greeting, from anime-colorscripts", `requires_plugins = ["greet"]`, tags `["look"]`, the rest empty/any.

`install.sh`:

```bash
#!/usr/bin/env bash
# anime install: fetch the pinned release of anime-colorscripts.
#
# The git tree of that project holds no sprites (its build scrapes them from
# the web), so the release tarball is the artefact, checked against a
# recorded checksum. Nothing here aborts `plugin add`: offline, or a download
# that does not match, leaves what is there and warns, and the doctor's own
# row is where a missing pack is reported.

ANIME_VERSION="v1.1.3"
ANIME_URL="https://github.com/juanlouisr/anime-colorscripts/releases/download/$ANIME_VERSION/anime-colorscripts.tar.gz"
# The sha256 of that asset, taken on 2026-09-13. Tests point
# NEKOSHELL_ANIME_SHA256 at a tarball of their own.
ANIME_SHA256="${NEKOSHELL_ANIME_SHA256:-7e7ad31618fa292875588e2cb1f0e99ff42bac7fcffc615697aafcf34e1db3f5}"
ANIME_DIR="$HOME/.local/share/anime-colorscripts"

if [[ -f "$ANIME_DIR/.nekoshell-version" && "$(cat "$ANIME_DIR/.nekoshell-version")" == "$ANIME_VERSION" ]]; then
  log_info "$PLUGIN_NAME: anime-colorscripts $ANIME_VERSION is already here"
else
  an_tmp="$(mktemp -d "${TMPDIR:-/tmp}/nekoshell-anime.XXXXXX")"
  if run curl -fsSL -o "$an_tmp/anime.tar.gz" "$ANIME_URL"; then
    if [[ "${NEKOSHELL_DRY_RUN:-0}" == "1" ]]; then
      : # nothing was downloaded
    elif [[ "$(shasum -a 256 "$an_tmp/anime.tar.gz" | cut -d' ' -f1)" != "$ANIME_SHA256" ]]; then
      log_warn "$PLUGIN_NAME: the download does not match the recorded checksum; keeping what is there"
    else
      run rm -rf "$ANIME_DIR"
      run mkdir -p "$ANIME_DIR"
      # The tarball's entries start with ./anime-colorscripts/.
      run tar -xzf "$an_tmp/anime.tar.gz" -C "$ANIME_DIR" --strip-components 2
      printf '%s\n' "$ANIME_VERSION" >"$ANIME_DIR/.nekoshell-version"
    fi
  else
    log_warn "$PLUGIN_NAME: could not download anime-colorscripts; the greeting will skip it"
  fi
  rm -rf "$an_tmp"
fi

true
```

`greet-art`:

```bash
#!/usr/bin/env bash
# anime greet-art: a random sprite from the anime-colorscripts pack, captioned
# with the character's name. The pack's own launcher is not used: it wants
# GNU coreutils on macOS, and picking a file needs neither it nor them.
# Keys from greet.conf: ANIME_ONLY (words; only names containing one are
# drawn) and ANIME_SKIP (words never drawn; the pack has one crude name).
set -uo pipefail
dir="$HOME/.local/share/anime-colorscripts/colorscripts"
[[ -d "$dir" ]] || exit 1
[[ -n "${NEKOSHELL_SEED:-}" ]] && RANDOM="$NEKOSHELL_SEED"
only="$(printf '%s' "${ANIME_ONLY:-}" | tr '[:upper:]' '[:lower:]')"
skip="$(printf '%s' "${ANIME_SKIP-fuck}" | tr '[:upper:]' '[:lower:]')"

# wanted NAME: true when NAME passes the ONLY and SKIP word lists.
wanted() {
  local name="$1" word keep=1
  for word in $skip; do [[ "$name" == *"$word"* ]] && return 1; done
  if [[ -n "$only" ]]; then
    keep=0
    for word in $only; do [[ "$name" == *"$word"* ]] && keep=1; done
  fi
  ((keep))
}

files=()
for f in "$dir"/*.txt; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f" .txt | tr '[:upper:]' '[:lower:]')"
  wanted "$base" && files+=("$f")
done
[[ ${#files[@]} -gt 0 ]] || exit 1
f="${files[$((RANDOM % ${#files[@]}))]}"
name="$(basename "$f" .txt)"
name="${name#[0-9]*-}"
printf '%s\n' "$name" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2) } 1'
cat "$f"
```

`doctor.sh`:

```bash
#!/usr/bin/env bash
# anime doctor: the pack, its version and how many sprites it holds.
an_dir="$HOME/.local/share/anime-colorscripts"
if [[ -d "$an_dir/colorscripts" ]]; then
  an_n="$(find "$an_dir/colorscripts" -name '*.txt' | wc -l | tr -d ' ')"
  report ok "anime-colorscripts" "$(cat "$an_dir/.nekoshell-version" 2>/dev/null || echo unknown), $an_n sprites"
else
  report fail "anime-colorscripts" "missing (nekoshell plugin add anime)"
fi
true
```

README (five sections) and `docs/plugins/anime.md` as for pokemon, with `ANIME_ONLY`, `ANIME_SKIP`, the `~/.local/share/anime-colorscripts` path and the `rm -rf` line. THIRD_PARTY: a fetched-at-install row (juanlouisr/anime-colorscripts, release v1.1.3, sha256 in `plugins/anime/install.sh`, MIT).

- [ ] **Step 5: Run, lint, commit**

Run: `bats tests/plugins/anime.bats tests/terminals/iterm2.bats && scripts/lint.sh` (iterm2's tests use the curl fake; they must still pass).

```bash
git add -A plugins/anime docs/plugins/anime.md tests/plugins/anime.bats tests/fakes/curl THIRD_PARTY.md
git commit -m "feat(anime): anime-colorscripts sprites as an art provider"
```

---

### Task 5: The minecraft and colorscripts providers

**Files:**

- Create: `plugins/minecraft/{plugin.toml,install.sh,greet-art,doctor.sh,README.md}`, `plugins/colorscripts/{plugin.toml,install.sh,greet-art,doctor.sh,scripts.txt,README.md}`, `docs/plugins/minecraft.md`, `docs/plugins/colorscripts.md`
- Modify: `tests/fakes/git` (fabricate each clone's layout), `THIRD_PARTY.md`
- Test: `tests/plugins/minecraft.bats`, `tests/plugins/colorscripts.bats`

**Interfaces:**

- Consumes: the provider contract.
- Produces: `~/.local/share/minecraft-colorscripts` at `e7186dd841a5362df6229dbc16209147ce716a3a`; `~/.local/share/colorscripts` at `7a8779775f922655564db9e518c6c7b5c4956a9a`. `MINECRAFT_PACK` (default `default-1.8.9`).

- [ ] **Step 1: The fake git fabricates the two layouts**

In `tests/fakes/git`'s `clone` case, add before `*)`:

```bash
      minecraft-colorscripts)
        mkdir -p "$dest/colorscripts/default-1.8.9"
        printf 'BLOCK stone\nrow2\n' >"$dest/colorscripts/default-1.8.9/stone.txt"
        printf 'BLOCK oak_planks\nrow2\n' >"$dest/colorscripts/default-1.8.9/oak_planks.txt"
        ;;
      colorscripts)
        mkdir -p "$dest/colorscripts"
        printf '#!/usr/bin/env bash\necho BARS\n' >"$dest/colorscripts/bars"
        printf '#!/usr/bin/env bash\necho PACMAN\n' >"$dest/colorscripts/pacman"
        printf '#!/usr/bin/env bash\necho NOTLISTED\n' >"$dest/colorscripts/notlisted"
        chmod +x "$dest"/colorscripts/*
        ;;
```

- [ ] **Step 2: Failing tests**

`tests/plugins/minecraft.bats` (setup as pokemon.bats): the contract test; "add clones at the pinned commit" (assert the clone URL `https://github.com/Axistorm1/minecraft-colorscripts.git` and `checkout --quiet e7186dd`); "greet-art captions the block and prints it" (`NEKOSHELL_SEED=1`, caption is `Stone` or `Oak Planks`, second line starts with `BLOCK`); "greet-art is silent before the clone"; "doctor reports the pack (`ok minecraft-colorscripts default-1.8.9, 2 blocks`) and fails when missing".

`tests/plugins/colorscripts.bats`: the contract test; the clone test (`https://github.com/theamallalgi/colorscripts.git`, `7a87797`); "greet-art runs only scripts on the vetted list" (over seeds 1..10 the captions are only `bars` and `pacman`, never `notlisted`; the sprite line is `BARS` or `PACMAN`); "scripts.txt names 32 scripts, one per line"; "doctor counts the vetted scripts that are present (`ok colorscripts 2 of 32 scripts`)".

- [ ] **Step 3: Run to verify they fail**

- [ ] **Step 4: Implementation**

`plugins/minecraft/install.sh`: the clone-and-pin shape of `plugins/pokemon/install.sh` with `MC_SHA="e7186dd841a5362df6229dbc16209147ce716a3a"`, `MC_DIR="$HOME/.local/share/minecraft-colorscripts"`, `MC_URL="https://github.com/Axistorm1/minecraft-colorscripts.git"`, no symlink onto PATH (the launcher is not used).

`plugins/minecraft/greet-art`:

```bash
#!/usr/bin/env bash
# minecraft greet-art: a random block from minecraft-colorscripts, captioned
# with its name. MINECRAFT_PACK in greet.conf picks the texture pack
# directory (default-1.8.9 is the only one shipped).
set -uo pipefail
pack="${MINECRAFT_PACK:-default-1.8.9}"
dir="$HOME/.local/share/minecraft-colorscripts/colorscripts/$pack"
[[ -d "$dir" ]] || exit 1
[[ -n "${NEKOSHELL_SEED:-}" ]] && RANDOM="$NEKOSHELL_SEED"
files=()
for f in "$dir"/*.txt; do [[ -f "$f" ]] && files+=("$f"); done
[[ ${#files[@]} -gt 0 ]] || exit 1
f="${files[$((RANDOM % ${#files[@]}))]}"
basename "$f" .txt | tr '_' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2) } 1'
cat "$f"
```

`plugins/colorscripts/scripts.txt`: the 32 names, one per line, in this order: `00default.sh alpha bars blocks1 blocks2 colortest colortest-slim crunch crunchbang-mini darthvader dna elfman faces fade ghosts jangofett monster mouseface pacman panes rails rally-x six space-invaders square tanks thebat2 tiefighter1 tiefighter1-no-invo tiefighter1row tiefighter2 zwaves` (every one measured at ≤ 5 ms on 2026-09-13; none animates).

`plugins/colorscripts/greet-art`:

```bash
#!/usr/bin/env bash
# colorscripts greet-art: one of the vetted ANSI pattern scripts, run in the
# terminal's own palette so it follows the flavour by itself. Only names in
# scripts.txt beside this file are run: they were timed at the pinned commit
# and none animates or waits, which is what keeps a shell start-up quick and
# a third-party script from doing anything but print.
set -uo pipefail
dir="$HOME/.local/share/colorscripts/colorscripts"
list="${PLUGIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}/scripts.txt"
[[ -d "$dir" && -r "$list" ]] || exit 1
[[ -n "${NEKOSHELL_SEED:-}" ]] && RANDOM="$NEKOSHELL_SEED"
names=()
while IFS= read -r n; do
  [[ -n "$n" && -f "$dir/$n" ]] && names+=("$n")
done <"$list"
[[ ${#names[@]} -gt 0 ]] || exit 1
n="${names[$((RANDOM % ${#names[@]}))]}"
printf '%s\n' "$n"
bash "$dir/$n" 2>/dev/null
```

Doctors: minecraft reports `PACK, N blocks`; colorscripts reports `N of M scripts` where M is the line count of scripts.txt, fail when the clone is missing. READMEs, docs pages and THIRD_PARTY rows (both MIT, commits above) as before.

- [ ] **Step 5: Run, lint, commit**

Run: `bats tests/plugins/minecraft.bats tests/plugins/colorscripts.bats tests/plugins/tmux.bats tests/plugins/pokemon.bats && scripts/lint.sh`

```bash
git add -A plugins/minecraft plugins/colorscripts docs/plugins tests/plugins tests/fakes/git THIRD_PARTY.md
git commit -m "feat: minecraft and colorscripts art providers"
```

---

### Task 6: The repository contract and the rest of the docs

**Files:**

- Modify: `tests/core/repo.bats`, `AGENTS.md`, `README.md`, `docs/INSTALL.md`, `docs/plugins/README.md`, `skills/nekoshell/SKILL.md`, `CHANGELOG.md`, `docs/superpowers/specs/2026-09-13-art-providers-and-plugins-design.md`

- [ ] **Step 1: Contract test**

Add to `tests/core/repo.bats`:

```bash
@test "every art provider is executable and requires greet" {
  local bad="" art dir name
  for art in "$REPO_ROOT"/plugins/*/greet-art; do
    [[ -e "$art" ]] || continue
    dir="$(dirname "$art")"; name="$(basename "$dir")"
    [[ -x "$art" ]] || bad="$bad
$name/greet-art: not executable"
    grep -qE '^requires_plugins *= *\[.*"greet".*\]' "$dir/plugin.toml" || bad="$bad
$name/plugin.toml: an art provider must list greet in requires_plugins"
  done
  if [[ -n "$bad" ]]; then echo "art provider contract violations:$bad" >&2; false; fi
}
```

- [ ] **Step 2: Docs**

- `AGENTS.md` "Adding a plugin": add "`greet-art`, an executable that prints a caption line and then a sprite (exit non-zero, silent, when it has nothing), makes the plugin an art provider for the greeting; it must list `greet` in `requires_plugins`."; the "Never" list keeps the copyrighted-image line and adds "Add a provider whose draw takes more than a few milliseconds: the greeting has a 150 ms budget."
- `README.md`: the greeting paragraph names the providers ("a Pokémon by default; anime, Minecraft blocks and ANSI patterns are one `plugin add` away"); the plugin list mentions the four.
- `docs/INSTALL.md`: the "left in place" sentence names the sprite packs under `~/.local/share/` (pokemon-colorscripts, anime-colorscripts, minecraft-colorscripts, colorscripts).
- `docs/plugins/README.md`: profiles table (`minimal`: modern-cli, greet, pokemon; dev and full likewise), the plugins table rows for pokemon, anime, minecraft, colorscripts, and a line in "Hooks you may notice" that `greet-art` makes a plugin an art provider.
- `skills/nekoshell/SKILL.md`: the description and the rollback sentence mention the sprite packs.
- `CHANGELOG.md` 0.2.0 "Plugins and profiles": "greet draws from art provider plugins (`greet-art`): pokemon (every profile), anime, minecraft and colorscripts; `ART` and `SPRITE_SHARE` in `greet.conf`; `nekoshell greet --art`." The count of shipped plugins becomes sixteen.
- Spec: in "Default", replace the migration sentence with "The profiles carry `pokemon`, so the next `nekoshell install` enables it; `nekoshell doctor` warns until then." In "The providers", replace "`--purge` removes it" with "the page gives the `rm -rf` line".

- [ ] **Step 3: Full check and commit**

Run: `make check` (lint + the whole suite).

```bash
git add -A
git commit -m "docs: art providers in the contract, the manual, the readme and the changelog"
```

---

### Task 7: Apply on this Mac, verify, open the PR

- [ ] **Step 1: Enable and time**

```bash
./bin/nekoshell plugin add pokemon anime minecraft colorscripts
./bin/nekoshell doctor --plugin greet
for i in 1 2 3 4 5 6; do env -u CLAUDECODE NEKOSHELL_GREET_TIME=1 NEKOSHELL_GREET_MODE=text ./plugins/greet/bin/nekoshell-greet | tail -1; done
./bin/nekoshell greet --art anime
./bin/nekoshell greet --art minecraft
./bin/nekoshell greet --art colorscripts
```

Expected: every doctor row ok, `greet: N ms` under 150 for each provider. Open a new kitty and a new Terminal.app window (`env -u CLAUDECODE open -a kitty`) and see the sprite.

- [ ] **Step 2: PR**

```bash
git push -u origin feat/art-providers
gh pr create --title "feat: art providers for the greeting: pokemon, anime, minecraft, colorscripts" --body-file - <<'PR'
## What

- greet is the engine: a plugin with an executable `greet-art` is an art provider; `ART` and `SPRITE_SHARE` in greet.conf pick among them; `nekoshell greet --art NAME`; stats alone when nothing draws; one doctor row per provider.
- pokemon: the Pokémon moved out of greet unchanged, in every profile.
- anime (release tarball, checksummed), minecraft (pinned clone), colorscripts (pinned clone, vetted list): three more providers.
- Docs: a page per plugin, the contract in AGENTS.md, THIRD_PARTY credits.

## Checks

- `make check` green; the suite grew by the provider tests.
- On this Mac: all four enabled, greeting timed under budget in kitty and Terminal.app.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PR
```

Wait for the eight checks; the user merges.
