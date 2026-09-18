import { author, repo } from '../data/content'

export function Footer() {
  return (
    <footer className="foot">
      <div className="wrap foot__in">
        <ul>
          <li><a href={repo} target="_blank" rel="noreferrer">GitHub</a></li>
          <li><a href={`${repo}/blob/main/docs/README.md`} target="_blank" rel="noreferrer">Docs</a></li>
          <li><a href={`${repo}/blob/main/CHANGELOG.md`} target="_blank" rel="noreferrer">Changelog</a></li>
          <li><a href={`${repo}/blob/main/CONTRIBUTING.md`} target="_blank" rel="noreferrer">Contributing</a></li>
          <li><a href={`${repo}/releases`} target="_blank" rel="noreferrer">Releases</a></li>
          <li><a href={`${repo}/blob/main/LICENSE`} target="_blank" rel="noreferrer">MIT licence</a></li>
        </ul>
        <span>by <a href={author.portfolio} target="_blank" rel="noreferrer">{author.name}</a></span>
      </div>
      <div className="wrap">
        <p>
          The sprites and pictures the greeting draws come from packs fetched at install time and are not part of the repository. The neko is the project's own model, MIT like the rest. Pokémon is a trademark of The Pokémon Company and Minecraft of Mojang. Catppuccin is the palette, made by the Catppuccin community.
        </p>
      </div>
    </footer>
  )
}
