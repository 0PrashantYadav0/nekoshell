#!/usr/bin/env python3
"""Generate data/pokemon.tsv from PokeAPI/pokeapi CSVs at a pinned commit.

Downloads pokemon_species.csv, pokemon.csv, pokemon_types.csv and types.csv from
https://raw.githubusercontent.com/PokeAPI/pokeapi/<sha>/data/v2/csv/ and writes one
row per species: name (the species identifier, lowercase and hyphenated, matching
what pokemon-colorscripts uses), national dex number, slash-joined capitalised
types, generation, height in metres and weight in kilograms. Facts only, no
Pokedex flavour text. Standard library only.

Pinned commit: 8fe210b21c9abbe73de93670f3d5a346c80a3625
(PokeAPI/pokeapi master, resolved 2026-09-11 via
`git ls-remote https://github.com/PokeAPI/pokeapi.git master`).
"""
import csv
import io
import urllib.request
from pathlib import Path

SHA = "8fe210b21c9abbe73de93670f3d5a346c80a3625"
BASE_URL = f"https://raw.githubusercontent.com/PokeAPI/pokeapi/{SHA}/data/v2/csv/"


def fetch_csv(filename):
    with urllib.request.urlopen(BASE_URL + filename) as resp:
        text = resp.read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(text)))


def main():
    species_rows = fetch_csv("pokemon_species.csv")
    pokemon_rows = fetch_csv("pokemon.csv")
    pokemon_type_rows = fetch_csv("pokemon_types.csv")
    type_rows = fetch_csv("types.csv")

    type_name_by_id = {r["id"]: r["identifier"] for r in type_rows}

    # The default pokemon for a species is the one to read height/weight/types
    # from. Prefer is_default == 1; fall back to the pokemon whose id matches
    # the species id (some species have no row flagged as default).
    default_pokemon_by_species = {}
    fallback_pokemon_by_species = {}
    for r in pokemon_rows:
        species_id = r["species_id"]
        if r["is_default"] == "1":
            default_pokemon_by_species[species_id] = r
        if r["id"] == species_id and species_id not in fallback_pokemon_by_species:
            fallback_pokemon_by_species[species_id] = r

    types_by_pokemon_id = {}
    for r in pokemon_type_rows:
        types_by_pokemon_id.setdefault(r["pokemon_id"], []).append(r)
    for pid, rows in types_by_pokemon_id.items():
        rows.sort(key=lambda r: int(r["slot"]))

    out_rows = []
    for sp in species_rows:
        species_id = sp["id"]
        pokemon = default_pokemon_by_species.get(species_id) or fallback_pokemon_by_species.get(species_id)
        if pokemon is None:
            continue
        type_rows_for_pokemon = types_by_pokemon_id.get(pokemon["id"], [])
        if not type_rows_for_pokemon:
            continue
        types = "/".join(type_name_by_id[r["type_id"]].capitalize() for r in type_rows_for_pokemon)
        height_m = f"{int(pokemon['height']) / 10:.1f}"
        weight_kg = f"{int(pokemon['weight']) / 10:.1f}"
        out_rows.append((sp["identifier"], int(species_id), types, sp["generation_id"], height_m, weight_kg))

    out_rows.sort(key=lambda r: r[1])

    out_path = Path(__file__).resolve().parent.parent / "data" / "pokemon.tsv"
    out_path.parent.mkdir(exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        f.write("name\tdex\ttypes\tgen\theight_m\tweight_kg\n")
        for name, dex, types, gen, height_m, weight_kg in out_rows:
            f.write(f"{name}\t{dex}\t{types}\t{gen}\t{height_m}\t{weight_kg}\n")

    print(f"wrote {len(out_rows)} rows to {out_path}")


if __name__ == "__main__":
    main()
