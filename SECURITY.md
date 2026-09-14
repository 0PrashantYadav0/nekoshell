# Security

## Reporting a problem

Use GitHub's private vulnerability reporting on this repository (Security tab, "Report a vulnerability"). If that is unavailable, open an issue with only the words "security: please contact me" and no detail; the maintainer replies with a private channel.

Do not post exploit details in a public issue or pull request.

## What counts

nekoshell writes files into your home directory, runs Homebrew, and renders configuration for your terminal and shell. Anything that would let a repository file, a plugin, a theme or an installer flag do more than that is in scope: writing outside `$HOME` and the Homebrew prefix, executing fetched content that is not pinned, or leaking a token such as the Spotify client id.

## Supported versions

The latest release on the main branch. Older tags receive no fixes.

## Response

Reports are acknowledged within seven days. A fix ships as a patch release with a CHANGELOG line that credits the reporter, unless they ask otherwise.
