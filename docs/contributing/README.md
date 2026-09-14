# Contributor guides

Longer walkthroughs than [CONTRIBUTING.md](../../CONTRIBUTING.md), which holds the rules themselves.

- [writing-a-plugin.md](writing-a-plugin.md): from `tests/fixtures/plugins/demo` to a plugin that passes `make check`, with the nine keys, the hooks, the two READMEs, the fake and the bats file.
- [writing-a-terminal-adapter.md](writing-a-terminal-adapter.md): the ten functions, the two places detection has to be taught, the colour template, the README and the CI matrix entry.
- [testing.md](testing.md): `tests/helpers.bash`, the fakes and their `FAKE_*` variables, the fixtures, running one test, and writing one for a bug.

Read first:

- [CONTRIBUTING.md](../../CONTRIBUTING.md): the setup, the checks, the commit message rules, the code rules.
- [AGENTS.md](../../AGENTS.md): the same contract in the shape an AI agent loads.
- [docs/ARCHITECTURE.md](../ARCHITECTURE.md): how the pieces fit, before changing one.
- [docs/ci-checks/](../ci-checks/README.md): what each CI job runs and how to reproduce it.
