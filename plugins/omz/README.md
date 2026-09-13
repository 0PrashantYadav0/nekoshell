# omz

## What it does

The two oh-my-zsh plugins worth keeping without oh-my-zsh: `git`, the aliases (`gst`, `gco`, `gp`, `gl`, `glog`, and a hundred more) and helper functions (`gcm`, `gbda`) most people know from an oh-my-zsh setup, and `web-search`, which gives `google`, `ddg`, `github`, `stackoverflow` and friends as commands that open a search in the browser. Both come straight from the oh-my-zsh repository, loaded by antidote alongside the other shell plugins, so `~/.oh-my-zsh` is not needed and nothing else of oh-my-zsh is loaded.

## Installs

Nothing from Homebrew. antidote clones oh-my-zsh into its own cache the first time a new shell starts after the plugin is added; that takes a few seconds once.

## Files

None in your home. The three lines go into `~/.config/nekoshell/antidote.txt`, which nekoshell regenerates from the enabled plugins.

## After install

Open a new shell and wait for the clone the first time. `alias | grep '^g'` lists what the git plugin defined; `google nekoshell` tries the other.

## Remove

`nekoshell plugin remove omz` takes the lines back out of `antidote.txt`; the next shell no longer loads them. The clone stays in antidote's cache until `antidote purge ohmyzsh/ohmyzsh`.
