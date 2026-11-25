#!/usr/bin/env python3
import re
from pathlib import Path
import pandas as pd

expected = {
    "Ancylostoma_ceylanicum": 53326,
    "Ascaris_lumbricoides": 6252,
    "Blastocystis_sp": 12968,
    "Cryptosporidium_hominis": 353151,
    "Cryptosporidium_parvum": 5807,
    "Cyclospora_cayetanensis": 88456,
    "Entamoeba_histolytica": 294381,
    "Enterocytozoon_bieneusi": 481877,
    "Giardia_duodenalis": 5741,
    "Homo_sapiens": 9606,
    "Necator_americanus": 51031,
    "Strongyloides_stercoralis": 6248,
    "Taenia_saginata": 6206,
    "Trichuris_trichiura": 36087,
}

rows = {}

for f in sorted(Path(".").glob("*.custom.abundance.tsv")):
    species = f.name.replace(".custom.abundance.tsv", "")
    if species not in expected:
        continue

    counts = {"On target": 0, "Ambiguous": 0, "Unassigned": 0, "Human": 0}

    for line in f.read_text().splitlines():
        name, count = line.rsplit("\t", 1)
        taxid = int(re.search(r"\(taxid (\d+)\)$", name).group(1))

        if taxid == 0:
            category = "Unassigned"
        elif species == "Homo_sapiens" and taxid == 9606:
            category = "On target"
        elif taxid == 9606:
            category = "Human"
        elif taxid == expected[species]:
            category = "On target"
        else:
            category = "Ambiguous"

        counts[category] += int(count)

    total = sum(counts.values())
    rows[species] = {k: 100 * v / total for k, v in counts.items()}

df = pd.DataFrame.from_dict(rows, orient="index")
df.index.name = "Species"

print(df.round(4).to_string())
df.round(4).to_csv("kraken2_custom_percentages.csv")
