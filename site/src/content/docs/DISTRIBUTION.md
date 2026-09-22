# Where nekoshell can be hosted

nekoshell is a directory of bash, zsh and Python scripts that runs from its own tree: `bin/nekoshell` finds everything else relative to itself, and `nekoshell.toml` records where that tree lives. Any host that can deliver the directory to a Mac and put `bin/nekoshell` on the PATH works. Three do today; the rest are things worth doing later.

## Homebrew tap

The recommended way in, and the one the release pipeline keeps up to date:

```bash
brew tap 0PrashantYadav0/nekoshell
brew install nekoshell
nekoshell install
```

`brew install` puts the tree in `libexec` and links `bin/nekoshell`; `nekoshell install` is the part that sets up your shell. Afterwards, `brew update && brew upgrade nekoshell` updates it, and `brew uninstall nekoshell` removes the package (run `nekoshell uninstall` first if you want your dotfiles back too). The formula records `#{HOMEBREW_PREFIX}/opt/nekoshell/libexec` as the root, so an upgrade keeps every link in your home directory valid.

`brew install --HEAD nekoshell` installs the current `main` instead of the newest release, for people who want the unreleased plugins.

The formula is not written by hand. `packaging/homebrew/nekoshell.rb.tmpl` in this repository is the only copy; `scripts/render-formula.sh --version X.Y.Z --sha256 HEX` fills in the url and the checksum, and the `tap` job of `.github/workflows/release.yml` pushes the result to `Formula/nekoshell.rb` in `0PrashantYadav0/homebrew-nekoshell` on every release. Editing the tap's copy by hand is pointless; the next release overwrites it.

The formulas the plugins need (`starship`, `eza`, `bat`, `fastfetch`, `spotify_player` and the rest) stay runtime installs through `nekoshell plugin add`, so the formula itself only depends on `bash`.

## The one-line installer

For people without Homebrew habits, or for a machine being set up from nothing:

```bash
curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash
```

`bootstrap.sh` downloads the latest Release's tarball, verifies it against the `SHA256SUMS` next to it, unpacks it as `~/.nekoshell` (an older release there is replaced, a git checkout there is pulled instead) and hands over to `install.sh`. Set `NEKOSHELL_REF` to pin another release, or a branch to get a git checkout that follows it:

```bash
NEKOSHELL_REF=v0.2.0 curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash
```

It needs nothing but `curl` (and `git` for a branch ref), and it installs the same verified artefact Homebrew does, so the Release's download count records it. A branch ref updates with every push, which is its trade-off: `NEKOSHELL_REF=main` gets whatever `main` is that day.

## A git checkout

What contributors use, and what [AGENTS.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/AGENTS.md) tells an agent to do:

```bash
git clone https://github.com/0PrashantYadav0/nekoshell.git ~/.nekoshell
cd ~/.nekoshell
./install.sh
```

The checkout is the install: `nekoshell.toml` points at it, so a `git pull` is an upgrade and edits to the tree take effect in the next shell. `make hooks` then installs the git hooks, and [CONTRIBUTING.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/CONTRIBUTING.md) covers the rest.

## GitHub Releases

Every tag `vX.Y.Z` gets a GitHub Release with two assets: `nekoshell-X.Y.Z.tar.gz`, a `git archive` of the tag with the `nekoshell-X.Y.Z/` prefix, and `SHA256SUMS`. The tarball holds what runs: `bin/`, `core/`, `plugins/`, `terminals/`, `profiles/`, `data/`, `install.sh`, `uninstall.sh`, `bootstrap.sh`, the licence and the docs a user reads. `tests/`, `scripts/`, `skills/`, `packaging/`, the contributor-only docs and the repository's own config files stay out, stripped by the `export-ignore` entries in `.gitattributes`. `scripts/package.sh` prints the tarball's size and entry count as it builds it, and refuses to write `SHA256SUMS` if `tests/` or `scripts/` made it in anyway. The release notes are that version's section of `CHANGELOG.md`.

To verify a download:

```bash
gh release download v0.2.0 --dir /tmp/rel
cd /tmp/rel && shasum -a 256 -c SHA256SUMS
```

The Homebrew formula points at the same tarball and pins the same checksum, so anything downstream that wants a stable artefact should use the Release rather than a tarball of the branch. [docs/ci-checks/release-process.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/ci-checks/release-process.md) in the repository describes how a release is cut; it is a contributor page, so it is one of the ones that does not ship in the tarball above.

## Later

Homebrew core. Once the tap has users, the same formula can go to `homebrew/core`, which makes it `brew install nekoshell` with no tap. Homebrew asks for a stable tagged release, an open-source license, a maintained repository and some notability; their guideline is roughly 75 GitHub stars or the equivalent. Worth doing later, not first.

Nix. A `flake.nix` would give Nix users `nix run github:0PrashantYadav0/nekoshell` and nix-darwin users a way to pin it in their system configuration. The thing to think through first is that the rig installs its tools with Homebrew, and a Nix user would expect those to come from Nix too.

MacPorts. A `Portfile` in the `macports-ports` repository, pointing at the release tarball, would install the tree under `${prefix}/libexec` and link the binary. A smaller audience than Homebrew, but some people only use MacPorts.

mise and asdf. `mise` installs any tool from a GitHub release with no plugin (`mise use github:0PrashantYadav0/nekoshell@v0.2.0`), and the Release already attaches an archive containing `bin/nekoshell`. An asdf plugin is a small repository with a `bin/install` script that downloads the same archive.
