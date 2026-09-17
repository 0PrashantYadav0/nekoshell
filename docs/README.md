# Documentation

Every page in this repository, grouped by what you came for. The front page is [README.md](../README.md); the pages marked "repository only" are contributor documentation and are stripped from the release tarball by `.gitattributes`, so they are linked here by URL rather than by path.

## Using nekoshell

- [INSTALL.md](INSTALL.md): the long install, the seven steps, the flags, the steps only you can do, the commands, upgrading, uninstalling and troubleshooting.
- [CONFIGURATION.md](CONFIGURATION.md): `nekoshell.toml`, the themes, the prompt, `greet.conf` and your own `local.zsh`.
- [TERMINALS.md](TERMINALS.md): what the five terminal adapters can do, how to configure them, and what each one still needs from you by hand.
- [plugins/README.md](plugins/README.md): how plugins are managed and what the profiles hold, with one page per plugin behind it.
- [REMOTE.md](REMOTE.md): installing nekoshell on another Mac over SSH, and what behaves differently there.

## Understanding it

- [ARCHITECTURE.md](ARCHITECTURE.md): one command, the libraries under it, the state it keeps in your home, the shell, the themes, the installer and the doctor.
- [plugins/ARCHITECTURE.md](plugins/ARCHITECTURE.md): what a plugin directory holds, what `add` and `remove` do, the hooks, the art provider contract and the music player contract.
- [DISTRIBUTION.md](DISTRIBUTION.md): the Homebrew tap, the one-line installer, a git checkout, the release tarball, and the hosts worth adding later.

## Contributing

- [Contributor guides](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/README.md) (repository only): longer walkthroughs for [writing a plugin](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/writing-a-plugin.md), [writing a terminal adapter](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/writing-a-terminal-adapter.md) and [writing a test](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/contributing/testing.md).
- [CI checks](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/ci-checks/README.md) (repository only): every job a pull request or a tag runs, the command that reproduces each one, and [how a release is cut](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/ci-checks/release-process.md).
- [CONTRIBUTING.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/CONTRIBUTING.md) (repository only): the setup, `make check`, the commit message rules and the code rules.
- [CODE_OF_CONDUCT.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/CODE_OF_CONDUCT.md) (repository only): the Contributor Covenant, and who to report to.
- [SECURITY.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/SECURITY.md) (repository only): which versions get fixes and how to report a vulnerability privately.
- [../THIRD_PARTY.md](../THIRD_PARTY.md): every vendored file with its source and licence, and everything the install hooks fetch with its pin.
- [../CHANGELOG.md](../CHANGELOG.md): what changed in each version.

## For AI agents

- [AGENTS.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/AGENTS.md) (repository only): the contract. The non-interactive install line, how to verify with `nekoshell doctor --json`, how to add a plugin or an adapter, and what never to do.
- [ai/README.md](https://github.com/0PrashantYadav0/nekoshell/blob/main/docs/ai/README.md) (repository only): installing nekoshell through an agent, the Claude Code skill, and the three plugins that dress AI coding tools in the flavour.
- [llms.txt](https://github.com/0PrashantYadav0/nekoshell/blob/main/llms.txt) (repository only): the same map as this page, in the form a language model reads.

## Also in this directory

`screenshots/` holds the images the README and the art provider pages use, and `assets/` holds the neko mascot; both are repository-only, as is `superpowers/`, which keeps the plans and specs behind larger changes.
