# omz

## What you get

Two pieces of oh-my-zsh without oh-my-zsh: the `git` plugin, with the aliases and helper functions most people know from an oh-my-zsh setup, and `web-search`, which turns search engines into commands that open the browser. antidote loads them straight from the ohmyzsh/ohmyzsh repository, together with oh-my-zsh's `lib/git.zsh` that the git plugin needs; `~/.oh-my-zsh` is not installed and nothing else of oh-my-zsh is loaded. The first new shell after adding the plugin clones the repository into antidote's cache, which takes a few seconds once.

## Using it

Git aliases and functions, among many: `gst`, `gco`, `gp`, `gl`, `glog`, `gcm`, `gbda`. `alias | grep '^g'` lists everything the plugin defined in this shell. Web search: `google`, `ddg`, `github`, `stackoverflow` and the rest of the plugin's engines, each taking the search terms as arguments, as in `google nekoshell`.

## Files

None in your home. Three lines go into `~/.config/nekoshell/antidote.txt`, which nekoshell regenerates from the enabled plugins: `ohmyzsh/ohmyzsh path:lib/git.zsh`, `ohmyzsh/ohmyzsh path:plugins/git` and `ohmyzsh/ohmyzsh path:plugins/web-search`. The clone lives in antidote's cache.

## Theme

None; nothing here carries a colour.

## Turning it off

`nekoshell plugin remove omz` takes the lines back out of `antidote.txt`; the next shell no longer loads them. The clone stays in antidote's cache until `antidote purge ohmyzsh/ohmyzsh`. `--purge` changes nothing here: the plugin installs nothing from Homebrew. The plugin has no doctor rows.
