# Assets

The project's mascot, the neko: a chibi black cat with green eyes sitting on a mauve prompt block. It is a 3D model, and this directory holds three files for it:

- `neko.stl`: the mesh, 7464 triangles in binary STL, z-up. GitHub renders the file as an interactive view, so clicking the mascot on the README opens it: drag to turn it.
- `neko.png`: a render of the mesh, 600 by 600 with a transparent background, which the README shows at the top, 240 pixels wide, above the badge row. It is a 3/4 view under one key light with cast shadows, a hemisphere ambient, highlights and a rim light, so it sits on either GitHub theme with its own contact shadow.
- `gen-neko.py`: the script that builds the mesh and renders the picture. Standard library only, like the other generators in this repository (`plugins/greet/scripts/gen-sample-art.py`, `plugins/pokemon/scripts/gen-pokemon-data.py`), so nothing needs installing; the cat is modelled from ellipsoids, cones, swept tubes and boxes in the file itself, and the render is a small software rasteriser with a shadow map. Colours are Catppuccin mocha.

The mascot is this repository's own work and carries the repository's MIT license, like everything here that [THIRD_PARTY.md](../../THIRD_PARTY.md) does not list. Nothing at runtime reads any of it, so `.gitattributes` keeps this directory out of the release tarball.

To change the mascot, edit `build()` or `render()` in the script and run it; it takes about ten seconds and rewrites both files. The render is then quantised, which the script does not do, to keep the file small:

```bash
python3 docs/assets/gen-neko.py
pngquant --quality 75-95 --speed 1 --strip --force --ext .png docs/assets/neko.png
```
