# Where nekoshell can be hosted

nekoshell is a directory of bash, zsh and Python scripts that runs from its own checkout: `bin/nekoshell` finds everything else relative to itself, and `nekoshell.toml` records where the checkout lives. Any host that can deliver that directory to a Mac and put `bin/nekoshell` on the PATH works. The options below are in the order they are worth doing.

## 1. GitHub, with a one-line bootstrap (already the case)

The repository itself is the primary host. `git clone` into `~/.nekoshell` and `./install.sh` is the documented path, and it is also what an AI agent following [AGENTS.md](../AGENTS.md) does.

A one-liner is a small addition: a `bootstrap.sh` at the root that clones (or pulls) `~/.nekoshell` and hands over to `install.sh`, served raw from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/0PrashantYadav0/nekoshell/main/bootstrap.sh | bash
```

Costs nothing, updates with every push to `main`, and needs no release process. The trade-off is that `main` is what people get; tag a release before you point anyone at it.

## 2. GitHub Releases

Tag a version (`git tag v0.2.0 && git push --tags`), and GitHub serves a tarball of the tree at that tag. A release workflow can attach a checksummed archive and generate notes from `CHANGELOG.md`. Releases are what the Homebrew formula, MacPorts port and Nix package below point at, so this is the step the others depend on.

## 3. A Homebrew tap (recommended first package)

The natural host for a macOS tool that already needs Homebrew. Create a repository named `homebrew-nekoshell` under your account with one file, `Formula/nekoshell.rb`, that downloads the release tarball, installs the tree into `libexec` and links `bin/nekoshell`:

```ruby
class Nekoshell < Formula
  desc "Catppuccin terminal rig for macOS: theme, greeting, Spotify panel, one CLI"
  homepage "https://github.com/0PrashantYadav0/nekoshell"
  url "https://github.com/0PrashantYadav0/nekoshell/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "<shasum -a 256 of the tarball>"
  license "MIT"

  depends_on "bash"
  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/nekoshell"
  end

  test do
    assert_match "nekoshell", shell_output("#{bin}/nekoshell version")
  end
end
```

Then anyone installs with:

```bash
brew tap 0PrashantYadav0/nekoshell
brew install nekoshell
nekoshell install
```

`brew upgrade` handles updates, `brew uninstall` removes it, and the tap can hold the fonts and tools as dependencies. The formulas the plugins need (`starship`, `eza`, `bat`, `fastfetch`, `spotify_player`, ...) stay as runtime installs through `nekoshell plugin add`, the way they are now, so the formula itself stays small.

## 4. Homebrew core

Once the tap has users, the same formula can be submitted to `homebrew/core`, which makes it `brew install nekoshell` with no tap. Homebrew asks for a stable tagged release, an open-source license, a maintained repository and some notability (their guideline is a project people have already found on their own, roughly 75 GitHub stars or equivalent). Worth doing later, not first.

## 5. MacPorts

The other macOS package manager. A `Portfile` in the `macports-ports` repository, pointing at the release tarball, installs the tree under `${prefix}/libexec` and links the binary. Smaller audience than Homebrew, but some people only use MacPorts.

## 6. Nix

A `flake.nix` in the repository gives Nix users `nix run github:0PrashantYadav0/nekoshell` and nix-darwin users a way to pin it in their system configuration. A package in `nixpkgs` follows the same recipe. The rig's dependence on Homebrew for the tools it installs is the thing to think through here: a Nix user would expect those to come from Nix too.

## 7. mise (and asdf)

`mise` can install any tool from a GitHub release with no plugin: `mise use github:0PrashantYadav0/nekoshell@v0.2.0`, provided the release attaches an archive containing `bin/nekoshell`. An `asdf` plugin is a small repository with a `bin/install` script that downloads the same archive. Useful for people who already manage every tool through one of these.

## 8. Bash package managers

`bpkg` and `basher` install a GitHub repository straight into a bash package directory and link the scripts named in a `package.json` (bpkg) or `package.sh` (basher). Very small audiences, but zero release work beyond one manifest file.

## 9. A macOS installer package

`pkgbuild` and `productbuild` turn the tree into a signed `.pkg` that installs with a double click, for people who do not open a terminal first. It needs an Apple Developer ID for notarisation or macOS will warn on open. Host the `.pkg` on GitHub Releases. Best kept for later, when there is a non-technical audience.

## 10. A documentation site

GitHub Pages can serve `docs/` (with MkDocs or plain Markdown rendering) at `0prashantyadav0.github.io/nekoshell`. It hosts the docs and screenshots, not the package, and gives the README somewhere to link to.

## What to do first

1. Tag `v0.2.0` and create the GitHub Release.
2. Create the `homebrew-nekoshell` tap with the formula above.
3. Add `bootstrap.sh` and the one-line install to the README for people without Homebrew habits.
4. Revisit Homebrew core, Nix and MacPorts once the tap has users.
