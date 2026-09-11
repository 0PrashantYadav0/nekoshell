# SDD ledger — plan: docs/superpowers/plans/2026-09-11-nekoshell-v0.1.md
Spec: docs/superpowers/specs/2026-09-11-nekoshell-v0.1-spec.md (reachable)
Branch: build/v0.1 (from main 5edb48d). Workspace: /Users/prashantkumaryadav/Downloads/Project/Config/.superpowers/sdd/2026-09-11-nekoshell-v0.1

## Pre-flight scan (2026-09-11)

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T1 lib/paths.sh vs T4/T6 bin scripts | bin scripts source ../lib/paths.sh by BASH_SOURCE; paths.sh derives root from its own path or ~/.config/nekoshell/root | consistent |
| T1 log.sh run() vs T2 iterm.sh, T6 backup.sh/install.sh | run prints "$ cmd" and skips under NEKOSHELL_DRY_RUN=1 | consistent; T6 dry-run test relies on it |
| T2 generator flags vs T2 iterm.sh, T6 tests | --root --out --window-type; guids identical in generator, iterm.sh, doctor, tests | consistent |
| T3 stow layout vs T6 install order | stow folds a missing ~/.config/nekoshell into one dir symlink, which would put local.zsh and root inside the repo | OK because install step 4 mkdir -p ~/.config/nekoshell/zsh runs before step 5 stow; dispatch will say so explicitly |
| T3 tests need stow, tomllib | stow not installed on this machine; python3 3.14 present | Ruling below (R1) |
| T4 greet timing | task text first uses date +%s%N then a note says macOS lacks %N and to use python only when timing is on | Ruling R2 |
| T4 fastfetch command module | config uses {"type":"command","text":...} | verified against json_schema.json before dispatch (see R3) |
| T6 doctor font check | `ls a b` exits non-zero if either path is missing, so the check fails even when the HOME font exists | Ruling R4 |
| T6 doctor tool checks vs test "only warns after fake install" | starship/fzf/eza/bat/zoxide are not installed on this machine; the test would see fail rows | Ruling R5 |
| T6 install prefs test | expects "install.sh --iterm-prefs" substring; install prints "$ROOT/install.sh --iterm-prefs" | consistent |
| T1 CI shellcheck line | uses a `|| fallback` hack because bin/ does not exist in Task 1 | Ruling R6 |
| T5 tests bash negative indices | ${lines[-2]} needs bash 4.3+; bats-core from Homebrew depends on Homebrew bash | acceptable, note in dispatch |
| T7 docs vs T8 screenshots | README links docs/screenshots/*.png that T8 creates | intended ordering |
| T8 window type | value 6 unverified; T8 iterates candidates | intended |

- Ruling: R1 Task 1 step 1 also installs stow (`brew install bats-core shellcheck stow`) — tests in T3/T6 need the real stow; cost if wrong: none, stow is in the Brewfile anyway.
- Ruling: R2 Task 4 implements timing with a now_ms() helper that calls python3 only when NEKOSHELL_GREET_TIME is set; the date +%s%N lines in the sample are superseded by the task's own note — cost if wrong: timing line missing, doctor warns.
- Ruling: R3 fastfetch json_schema (dev) confirms the `command` module takes `text`, `key`, `keyColor`; `display.color` accepts {keys,title}; `display.separator` is a string — Task 4 config stands as written; cost if wrong: fastfetch rejects the config and the greeting prints nothing.
- Ruling: R4 Task 6 doctor font check must test each candidate path with a glob loop, not one ls over two globs — cost if wrong: false fail row.
- Ruling: R5 Task 6 adds one-line echo fakes for starship, fzf, eza, bat, zoxide under tests/fakes so the doctor test is hermetic — cost if wrong: test coupling to fakes, acceptable.
- Ruling: R6 Task 1 CI runs `shellcheck -x $(git ls-files 'install.sh' 'uninstall.sh' 'lib/*.sh' 'bin/*' 'tests/helpers.bash')` so it grows with the repo — cost if wrong: CI misses a file; the local step 7 command still covers it.

## Progress

Task 1: dispatched (base cfafdb3, implementer model sonnet)
Task 1: review approved; ⚠️ commit trailers verified by controller (git log -1 51f40f5 shows both lines)
Task 1: minor (deferred): tests do not cover log_info/log_warn/log_step or the ~/.config/nekoshell/root override in lib/paths.sh (plan-inherited)
- Ruling: R7 CI brew install line lacks stow; Task 3 (whose tests need stow) adds `stow` to `.github/workflows/check.yml` — cost if wrong: CI fails on T3 tests until fixed.
Task 1: complete (commits cfafdb3..51f40f5, review clean)
Task 2: dispatched (base 51f40f5, implementer model sonnet)
Task 2: implementer DONE (commit 0069ed9, 11/11 tests); review dispatched (model sonnet)
Task 2: review approved
Task 2: minor (deferred): lib/iterm.sh has no guard for missing run/ITERM_DYNAMIC_DIR/NEKOSHELL_ROOT when sourced out of order (plan-inherited)
Task 2: complete (commits 51f40f5..0069ed9, review clean)
Task 3: dispatched (base 0069ed9, implementer model sonnet)
Task 3: implementer DONE_WITH_CONCERNS (commit 038a739): stow folding makes tests write local.zsh into the repo tree
- Ruling: R8 all stow invocations use `--no-folding` (tests' stow_it now; install.sh/uninstall.sh in Task 6) so ~/.config/nekoshell is always a real directory; tests also mkdir the zsh dir before stowing; add `stow/config/.config/nekoshell/zsh/local.zsh` to .gitignore — cost if wrong: a few more symlinks per install, none functional.
Task 3: pre-review fix requested from implementer (R8)
Task 3: fix landed (758f434), tree clean; review dispatched over 0069ed9..758f434 (model sonnet)
Task 3: review approved
Task 3: minor (deferred): lib/zsh_migrate.sh is mode 755 while other lib files are 644; `*ZSH=*` filter over-matches e.g. ZSH_THEME (plan-mandated)
Task 3: complete (commits 0069ed9..758f434, review clean)
Task 4: dispatched (base 758f434, implementer model sonnet)
- Ruling: R9 Task 3 commits carry "Co-Authored-By: Claude Sonnet 5" (the subagent harness's own attribution) instead of the required Fable 5.1 line. Before the final push, normalize trailers on build/v0.1 in one pass (git filter-branch --msg-filter, unpushed branch) so every commit ends with the Fable 5.1 line, keeping any subagent line above it — cost if wrong: history rewrite on an unpushed branch, no external effect.
Task 4: implementer DONE_WITH_CONCERNS (b6ff2a9, 30/30 tests; test-harness adjustments for script pty, bash 3.2 lines[-1], ); review dispatched (model opus)
Task 4: review needs fixes — I1 unguarded source of lib/paths.sh breaks silence guarantee; I2 `| sed` in tests' greet() voids $status assertions; ⚠️ stdin on image path resolved by controller: add </dev/null (real gap)
Task 4: minor (deferred): shellcheck source= directive should use SCRIPTDIR form; nekoshell-art add accepts non-image files; `sample` untested; GENERATIONS with spaces passed as one arg; ff_config ignores XDG_CONFIG_HOME
Task 4: fix round 1/5 dispatched (fix base b6ff2a9)
Task 4: fix landed 3069b59 (30/30); scoped re-review dispatched over b6ff2a9..3069b59 (model sonnet)
Task 4: fix round 1/5 (4 addressed, 0 open — source guard, greet() status, </dev/null, newline guard; commits b6ff2a9..3069b59)
Task 4: complete (commits 758f434..3069b59, review clean after 1 fix round)
Task 5: dispatched (base 3069b59, implementer model sonnet)
Task 5: implementer DONE (7f6b8f7, 35/35); review dispatched (model sonnet)
Task 5: review — Important: unguarded `spotify` calls in remote loop under set -e; ⚠️ "neither tool" branch untested resolved by controller: plan scope, deferred as minor
Task 5: minor (deferred): "neither tool" message misleading when --remote is passed with spotify_player present; "neither tool" branch has no test; brief lists lib/paths.sh as consumed but the script never needs it
Task 5: fix round 1/5 dispatched (fix base 7f6b8f7)
Task 5: fix landed 4b91322 (36/36); scoped re-review dispatched (model sonnet)
Task 5: fix round 1/5 (1 addressed, 0 open — guarded remote dispatches + survival test; commits 7f6b8f7..4b91322)
Task 5: minor (deferred): `spotify_player authenticate` failing under set -e exits the launcher (arguably desired: no launch without auth)
Task 5: complete (commits 3069b59..4b91322, review clean after 1 fix round)
Task 6: dispatched (base 4b91322, implementer model opus)
Task 6: implementer DONE_WITH_CONCERNS (2ded843, 45/45; deviations: -ef link check, backup list from stow leaves, gitconfig marker, doctor clears CLAUDECODE/TMUX); review dispatched (model opus)
Task 6: review needs fixes — I1 (plan-mandated) second uninstall run rm -rf's restored files before failing
- Ruling: R10 I1 is fixed despite being plan-mandated: data loss on a plausible action outweighs plan text. Fix = guard each manifest entry with an existence check before rm, and rename manifest.txt to manifest.restored after a successful restore. Also folded into the same round: ERR trap after the backup step pointing at uninstall.sh (#4), --check before preflight (#10), executable assertion on the pokemon symlink (#8), bystander-file test (#9) — cost if wrong: a few extra lines; all low risk.
Task 6: minor (deferred): backup derivation ignores stow's default ignore list (#2); alias migration skipped for symlinked ~/.zshrc with a misleading log (#3); uninstall leaves gitconfig include and pokemon symlink (#5); --json does not escape backslashes (#6); package list "zsh config" repeated in three places (#7)
Task 6: fix round 1/5 dispatched (fix base 2ded843)
Task 6: fix landed 5fce9fa (47/47; also set -E for the ERR trap); scoped re-review dispatched (model sonnet)
Task 6: fix round 1/5 (5 addressed, 0 open — restore guard + manifest.restored + second-uninstall test, ERR trap with set -E, --check before preflight, -x assertion, bystander test; commits 2ded843..5fce9fa)
Task 6: complete (commits 4b91322..5fce9fa, review clean after 1 fix round)
Task 7: dispatched (base 5fce9fa, implementer model sonnet)
Task 7: implementer DONE (9356a8b, 49/49); review dispatched (model sonnet)
- Ruling: R11 iTerm2 on this Mac was not installed through Homebrew, so `cask "iterm2"` in the Brewfile would make `brew bundle` fail (app already at /Applications) and abort the install at step 2. Task 8 removes that line from the Brewfile (preflight already requires iTerm2 to be present) and fixes any doc that lists it, before running the installer — cost if wrong: users without iTerm2 must install it by hand, which INSTALL.md already tells them.
Task 7: review needs fixes — I1 (plan-mandated) AGENTS.md/SKILL.md say warn is acceptable only for spotify and iterm2 prefs; greet time can warn too
- Ruling: R12 fix the contract to match the code: only `fail` rows block; `warn` rows are expected for spotify, iterm2 prefs and greet time — cost if wrong: an agent might proceed past a slow greeting, which the doctor reports but does not block on anyway.
Task 7: fix round 1/5 dispatched (fix base 9356a8b)
Task 7: fix landed 8947eb5; scoped re-review dispatched (model sonnet)
Task 7: fix round 1/5 (1 addressed, 0 open — doctor warn rule; commits 9356a8b..8947eb5)
Task 7: complete (commits 5fce9fa..8947eb5, review clean after 1 fix round)
Task 8: dispatched (base 8947eb5, implementer model opus) — real install on the owner's Mac per the approved plan; carries R11
Task 8: implementer DONE_WITH_CONCERNS (c1e9e0b): install succeeded on the owner's Mac (doctor 14 ok / 2 warn / 0 fail, greet 88 ms, backup ~/.local/share/nekoshell/backup/20260911T072840Z); Brewfile lost `cask "iterm2"` (R11) and the deprecated `tap "homebrew/bundle"`; doctor timing regex fixed for real ANSI output; 3 zsh tests made marker-based. Screenshots and window-type verification BLOCKED on human-only permissions (Screen Recording for iTerm2; iTerm2 AppleScript "create window" confirmation dialog).
- Ruling: R13 screenshots and the window-type pin become a human-gated follow-up after the final review (owner grants Screen Recording + approves the iTerm2 AppleScript prompt, then a short capture dispatch). The README image links stay in place pointing at the paths the follow-up will create — cost if wrong: two broken image links on the README until the follow-up lands.
Task 8: review dispatched over 8947eb5..c1e9e0b (model sonnet)
Task 8: complete (commits 8947eb5..c1e9e0b, review clean; screenshots + window type human-gated per R13)
Final review: dispatched over 5edb48d8f7997dbe048599845c6eba6737447c3c..c1e9e0b (model fable)
Final review: With fixes — C1 panel PATH, C2 backups inside the documented clone path, I1..I7, M1..M12; deferred triage: fix T3 chmod 644 and T6#3 symlinked-zshrc migration before merge.
- Ruling: R11 amended — its premise (preflight checks iTerm2) was false; I1 adds the preflight check and doc remedy. Cost if wrong: none.
- Ruling: R14 documented clone path becomes `~/.nekoshell` (data stays at ~/.local/share/nekoshell); install.sh refuses when the backup root is inside the checkout; `/backup/` gitignored — cost if wrong: early users must re-clone; none exist yet.
- Ruling: R15 greet.conf leaves the stow tree and becomes a template copied once on install (like local.zsh) — cost if wrong: users lose nothing; defaults live in the script.
- Ruling: R16 planning docs (docs/superpowers, wayfinder) stay in the public tree; the one absolute home path in the plan is scrubbed — cost if wrong: repo carries planning history, which the owner asked for as part of an open project.
- Ruling: R17 fix wave includes C1, C2, I1-I7, M1, M3, M4, M6, M8, M9, M10, M11 (network guard only), T3 chmod, T6#3; M2, M5, M12 and the rest stay deferred — cost if wrong: minor polish left for a later release.
Final review: fix wave dispatched (fix base c1e9e0b, model opus)
Final review: fix-wave agent stalled (no changes, tree clean at c1e9e0b); re-dispatched with the same brief (model opus)
Final review: fix wave agent stalled (no changes); re-dispatched (fix base c1e9e0b, model opus)
- Ruling: R18 owner requested (2026-09-11, mid-run) "short info about the Pokémon": added as Task 9 (brief written to task-9-brief.md; appended to the plan after the fix wave lands to avoid concurrent edits). Facts only (dex number, type, generation) from PokéAPI CSV data at a pinned commit; no Pokédex flavour text (copyrighted). Runs after the fix wave, before the scoped re-review, so one re-review covers both — cost if wrong: a data file of ~1000 rows in the repo and one awk lookup per greeting.
Task 9: queued (waits for the fix-wave commit)
- Ruling: R19 owner requested (2026-09-11, mid-run) richer greeting (storage, Wi-Fi, IP, battery; drop kernel/font), a two-line information prompt with the full cwd, configurable colour theme, and "aesthetic + functional" polish. Added as Tasks 10, 11, 12 (briefs written). Order after the fix wave: 9, 10, 11, 12, each with its task review; then ONE scoped final re-review over the whole post-review range; then trailers, push, PR. The polish list in Task 12 is fixed by the controller so the scope is bounded — cost if wrong: extra sessions; the owner asked for these.
Tasks 10-12: queued
Final review: fix wave landed 3a429b1 (58/58; helpers.bash moved the test HOME under $TMPDIR because the new nested-backup guard fired on tests/tmp)
Tasks 9-12 appended to the plan (commit after 3a429b1)
Task 9: dispatched (implementer model sonnet)
Task 9: implementer DONE_WITH_CONCERNS (c6b1afc, 60/60; test sources function via temp file, bash 3.2 quirk); review dispatched (model sonnet)
Task 9: complete (commits ef133af..c6b1afc, review clean)
Task 10: dispatched (base c6b1afc, implementer model sonnet)
Task 10: implementer DONE (859a4ce, 64/64); review dispatched (model sonnet)
Task 10: review needs fixes — I1 (plan-mandated) format string's raw newline + $line_break renders a blank row between line 1 and the character
- Ruling: R20 fix it (the brief's string was wrong): `$time$line_break$character` on one line — cost if wrong: none.
Task 10: minor (deferred): unused strip_jsonc helper in tests/fastfetch_config.bats (fold into the fix); `compact` on localip unverifiable on a single-NIC machine
Task 10: fix round 1/5 dispatched (fix base 859a4ce)
Task 10: fix landed b06f738 (65/65); scoped re-review dispatched (model sonnet)
Task 10: fix round 1/5 (2 addressed, 0 open; commits 859a4ce..b06f738)
Task 10: complete (commits c6b1afc..b06f738, review clean after 1 fix round)
Task 11: dispatched (base b06f738, implementer model opus)
Task 11: implementer DONE_WITH_CONCERNS (f8dc47c, 74/74): lazygit/config.yml and spotify-player/theme.toml stay mocha (deferred, needs a follow-up); theme_clear_stale_link added for the pre-existing ~/.config/starship.toml stow link; bat/config and delta.gitconfig lost their hardcoded mocha theme names so theme.zsh/BAT_THEME wins
Task 11: minor (deferred): lazygit and spotify_player themes are mocha-only; the owner's machine still has the old stow link for starship.toml until the next `./install.sh --yes`
Task 11: review dispatched (model opus)
Task 11: review needs fixes — I1 theme_clear_stale_link fails open on relative links whose target dir was deleted (fastfetch); nekoshell-theme half-applies a flavour on the upgrade path
Task 11: minor (deferred): install.sh RENDERED_PATHS unquoted word split; uninstall may restore a dangling fastfetch link from an upgrade-path backup; lazygit `delta --dark` conflicts with light flavours (carry into the lazygit/spotify_player theme follow-up); CHANGELOG "14 ok" headline stale; tests/install.bats never seeds a pre-existing fastfetch config
Task 11: fix round 1/5 dispatched (fix base f8dc47c)
Task 11: fix landed f89a3c7 (77/77): broken links at the two rendered paths are treated as stale; theme_apply orders renders before recording the flavour
- Ruling: R21 the implementer noted `bat cache --build` is never run, so bat cannot see the vendored tmTheme files (bat reports an unknown theme). Task 12 adds `run bat cache --build` to install.sh (when bat is present) and to theme_apply after writing theme.zsh, plus a doctor check that `bat --list-themes` contains the flavour — cost if wrong: one extra command per install.
Task 11: scoped re-review dispatched (model sonnet)
Task 11: fix round 1/5 (5 addressed, 0 open; commits f8dc47c..f89a3c7)
Task 11: complete (commits b06f738..f89a3c7, review clean after 1 fix round)
Task 12: dispatched (base f89a3c7, implementer model opus) — carries R21 (bat cache --build)
Task 12: implementer DONE_WITH_CONCERNS (fb8efb9, 103 tests): status bar keys partly unverified (visual check by owner); dimming keys moved to app prefs; doctor will fail `tool: atuin` on the owner's Mac until brew bundle runs; claim that bare [[ ]] does not fail a bats test (reviewer to verify)
Task 12: review dispatched (model opus)
- Ruling: R22 confirmed by the controller (bats 1.14.0 on this Mac): a failing `[[ ]]` that is not the last statement of a test does not fail the test; `[ ]` and commands do. Every mid-test `[[ ... ]]` assertion in tests/*.bats is therefore vacuous. Fix in the final wave: add `assert_contains`, `assert_not_contains`, `assert_matches` helpers to tests/helpers.bash (plain functions returning 1 on failure, which DOES fail the test) and convert every `[[ ]]` assertion; prove the conversion by breaking one assertion on purpose and watching it fail — cost if wrong: none; tests only get stricter and any latent real failure surfaces.
Task 12: review approved with 2 Important (fatal curl for shell integration; bat theme warn branch untested) + minors (spring knob key wrong for algorithm 0; README status-bar edit ambiguous; CHANGELOG hardware block stale; stale doctor comment; run_quiet hides stderr; FZF_CTRL_R_OPTS dead with atuin)
- Ruling: R23 Task 12's fix round and the R22 assertion conversion run as ONE dispatch (same implementer, context intact), followed by ONE scoped re-review; then trailers, push, PR — cost if wrong: a larger re-review diff.
Task 12: fix round 1/5 dispatched (fix base fb8efb9) — includes R22
Task 12: fix landed 7df8b18 (105 tests; 52 assertions converted incl. bare '! cmd'); scoped re-review dispatched (model opus)
- Ruling: R24 owner requested (2026-09-11) Neovim and tmux, and pointed at AeroSpace as a tmux alternative. Added Task 13 (nvim + tmux, themed, templates copied once) and Task 14 (AeroSpace opt-in behind `install.sh --aerospace`, separate Brewfile.aerospace so the default install never adds the tap; ⌥M stays with the panel; panel window floats). Both run after the current scoped re-review, each with its task review, then one scoped re-review over 13+14, then trailers, push, PR — cost if wrong: two more sessions; the owner asked.
Tasks 13-14: queued (briefs written)
Task 12: fix round 1/5 (10 addressed incl. R22, 0 open; commits fb8efb9..7df8b18)
Task 12: complete (commits f89a3c7..7df8b18, review clean after 1 fix round)
Task 12: minor (deferred): theme.bats:68 assert_not_contains on a possibly-missing file (add a -f check); assert_matches arity hazard for future call sites
Tasks 13-14 appended to the plan (commit after 7df8b18)
Task 13: dispatched (implementer model opus)
Task 13: implementer DONE_WITH_CONCERNS (4e64132, 123 tests): parse checks skipped (no nvim/tmux here); catppuccin/tmux v2.3.0 option form; existing-nvim-config concern
- Ruling: R25 the reviewer may `brew install neovim tmux` (both in the Brewfile the owner asked for; installs under /opt/homebrew, not HOME) and run the parse checks and a headless `nvim --headless "+Lazy! sync" +qa` with XDG_* dirs pointed at a temp dir, to prove the config loads — cost if wrong: two packages the owner wanted anyway.
- Ruling: R26 an existing `~/.config/nvim` (init.lua or init.vim) is the user's: the installer must skip the nvim template entirely and log it, never mix files in; when absent it copies the whole templates/nvim tree. Fix round after review — cost if wrong: users with a Neovim setup keep theirs, which is the safe direction.
Task 13: review dispatched (model opus)
Task 13: review needs fixes — I1 existing nvim config mixed/orphaned (R26 not met; init.vim and ~/.tmux.conf unhandled); I2 TPM cloned to ~/.tmux/plugins while TPM uses ~/.config/tmux/plugins for an XDG config (pin defeated, dead if-shell guard, wrong docs). Real-tool runs (nvim 0.12.5, tmux 3.7c) all clean.
- Ruling: R27 an existing `~/.tmux.conf` is treated like an existing nvim config: skip the tmux template and log it (tmux would otherwise silently prefer our XDG file) — cost if wrong: users with a tmux config keep theirs.
Task 13: minor (deferred): theme.sh hardcodes $HOME/.config/tmux (house style); lualine could pin catppuccin-nvim
Task 13: fix round 1/5 dispatched (fix base 4e64132)
Task 13: fix landed aa4e191 (130 tests, 0 skips); scoped re-review dispatched (model sonnet)
Task 13: fix round 1/5 (7 addressed, 0 open; commits 4e64132..aa4e191)
Task 13: complete (commits 4584812..aa4e191, review clean after 1 fix round)
Task 14: dispatched (base aa4e191, implementer model sonnet)
Task 14: implementer DONE (0715352, 142 tests); review dispatched (model sonnet)
Task 14: review needs fixes — I1 tests/aerospace.bats "doctor never fails" asserts unreachable strings ("fail  aerospace" with two spaces; "fail tool: aerospace"); minors: README table lacks alt-slash/alt-comma; config-version comment
Task 14: fix round 1/5 dispatched (fix base 0715352)
Task 14: fix landed 3abdadb (142 tests); scoped re-review dispatched (model sonnet); config-version=2 persistent-workspace note deferred
Task 14: fix round 1/5 (3 addressed, 0 open; commits 0715352..3abdadb)
Task 14: complete (commits aa4e191..3abdadb, review clean after 1 fix round)
Task 14: minor (deferred): config-version = 2 drops v1's inferred persistent workspaces 1-5 (add persistent-workspaces if wanted)
- Ruling: R28 the SDD ledger is committed to the repo as docs/superpowers/plans/2026-09-11-nekoshell-v0.1-ledger.md (consistent with R16 keeping planning docs public) and the gitignored workspace is deleted afterwards per the skill — cost if wrong: one more planning file in the tree.
All tasks complete. Trailer normalization (R9), push, PR next.
