# Gut eukaryote detection benchmark

A technical benchmark investigating why intestinal eukaryotic pathogens were poorly detected in metagenomic (MGX) datasets: **are their reads lost during human host removal, or are relevant genomes missing from the Kraken2 reference database?**

## Tests

1. **Simulate reads:** Generate NovaSeq-like 150 bp paired-end reads at approximately 10× genome coverage with InSilicoSeq from 13 gut eukaryote genomes (protozoa, microsporidia and helminths) and human GRCh38.p14 (`GCF_000001405.40`). Read IDs identify their source species.
2. **Test host removal:** Pool the simulated reads and filter against GRCh38 using Hostile and HoCoRT (both with Bowtie2). Tally host-negative and host-positive read pairs by source species.
3. **Test Kraken2 database representation:** Classify the Hostile host-negative reads against (a) a standard PlusPFP database and (b) a custom database containing the pathogen and human reference genomes. Compare assignments with the known source species.

## Results

### 1. Host removal

The table shows the percentage of simulated read pairs retained as **host-negative** or classified as **host-positive**, by source genome. Hostile and HoCoRT produced identical species-level tallies with their Bowtie2 workflows.

| Source species | Host-negative (%) | Host-positive (%) |
|---|---:|---:|
| *Ancylostoma ceylanicum* | 99.9947 | 0.0053 |
| *Ascaris lumbricoides* | 99.9784 | 0.0216 |
| *Blastocystis* sp. | 99.9254 | 0.0746 |
| *Cryptosporidium hominis* | 99.9761 | 0.0239 |
| *Cryptosporidium parvum* | 99.9832 | 0.0168 |
| *Cyclospora cayetanensis* | 99.9997 | 0.0003 |
| *Entamoeba histolytica* | 99.9951 | 0.0049 |
| *Enterocytozoon bieneusi* | 99.9837 | 0.0163 |
| *Giardia duodenalis* | 99.9995 | 0.0005 |
| **Homo sapiens** | **4.8867** | **95.1133** |
| *Necator americanus* | 99.9910 | 0.0090 |
| *Strongyloides stercoralis* | 99.9976 | 0.0024 |
| *Taenia saginata* | 99.9333 | 0.0667 |
| *Trichuris trichiura* | 99.9917 | 0.0083 |

All 13 pathogen genomes retained at least **99.925%** of read pairs. Host removal classified **95.11%** of simulated human read pairs as host-positive, leaving **4.89%** in the host-negative set. The two tools used the same aligner with comparable settings, so these results do not constitute an independent aligner comparison.

### 2. Kraken2: standard versus custom database

Both databases were tested against the same Hostile host-negative reads.

| Kraken2 database | Classified pairs | Classified (%) | Unclassified pairs | Unclassified (%) |
|---|---:|---:|---:|---:|
| Standard PlusPFP | 4,670,303 | 9.95 | 42,278,512 | 90.05 |
| Custom human + gut eukaryotes | 41,206,858 | 87.77 | 5,741,957 | 12.23 |

Using the standard PlusPFP database, only **2 of the 13** pathogens appeared under their expected species names. Selected assignments from that report were:

| Assignment in standard database | Assigned read pairs | Approximate proportion of expected host-negative pairs |
|---|---:|---:|
| *Giardia duodenalis* | 389,168 | 96.66% of *Giardia* pairs |
| *Cryptosporidium parvum* | 594,602 | 98.91% of combined *C. hominis* and *C. parvum* pairs |
| *Homo sapiens* | 969,167 | 18.04% of residual human pairs |

These approximate proportions compare **aggregate Kraken2 taxon counts** against expected source counts, not read-ID-matched truth. In particular, the standard database largely assigned the two *Cryptosporidium* sources under *C. parvum*.

### 3. Kraken2: custom database, per-species assignments

Percentages below use the known source species of each simulated read pair. The custom database contains the same reference assemblies used for simulation.

| Source species | On target (%) | Ambiguous (%) | Unassigned (%) | Human (%) |
|---|---:|---:|---:|---:|
| *Ancylostoma ceylanicum* | 98.0966 | 0.0064 | 1.8395 | 0.0576 |
| *Ascaris lumbricoides* | 99.4890 | 0.0384 | 0.4288 | 0.0438 |
| *Blastocystis* sp. | 99.6683 | 0.0037 | 0.3232 | 0.0048 |
| *Cryptosporidium hominis* | 98.1166 | 1.7504 | 0.1228 | 0.0101 |
| *Cryptosporidium parvum* | 98.3367 | 1.4992 | 0.1457 | 0.0184 |
| *Cyclospora cayetanensis* | 99.8856 | 0.0090 | 0.0859 | 0.0195 |
| *Entamoeba histolytica* | 98.1605 | 0.0305 | 1.7541 | 0.0549 |
| *Enterocytozoon bieneusi* | 99.4653 | 0.0412 | 0.4772 | 0.0163 |
| *Giardia duodenalis* | 96.6414 | 0.0112 | 3.3474 | 0.0000 |
| **Homo sapiens** | **0.0507** | **0.0001** | **99.9492** | **0.0000** |
| *Necator americanus* | 99.7055 | 0.1160 | 0.1055 | 0.0730 |
| *Strongyloides stercoralis* | 96.6671 | 0.0725 | 3.1730 | 0.0874 |
| *Taenia saginata* | 99.0627 | 0.0064 | 0.9256 | 0.0053 |
| *Trichuris trichiura* | 99.9971 | 0.0008 | 0.0021 | 0.0000 |

- **On target:** Assigned to the expected source species (including human for the human input).
- **Ambiguous:** Assigned to another non-human taxon, including other species or higher taxonomic ranks; not strictly a measure of taxonomic ambiguity.
- **Unassigned:** Kraken2 taxid 0.
- **Human:** Pathogen-derived reads assigned to taxid 9606. For the human input, human assignments are counted as **On target** instead.

Correct species-level assignments for the 13 pathogens ranged from **96.64% to 99.997%**. The largest off-target/higher-rank fractions occurred for *C. hominis* (1.75%) and *C. parvum* (1.50%). Most residual human reads were unclassified (**99.95%**).

## Conclusion

In this controlled simulation, **host removal caused negligible loss of the tested gut eukaryote reads**. The much better classification using a custom Kraken2 database suggests that **reference representation, rather than overly stringent host depletion, was the principal limitation** in the original classification test.

This is a **best-case classification benchmark**: simulated reads originated from the same assemblies used to construct the custom database. It does not establish sensitivity for divergent organisms, low-abundance infections or real MGX/MTX samples. The residual human reads also merit further investigation.

## Software

| Software | Version / model |
|---|---|
| Hostile | 2.0.2 |
| HoCoRT | 1.2.2 |
| Kraken2 | 2.1.3 |
| pandas | 1.4.3 |
| InSilicoSeq | Built-in NovaSeq model; version not recorded |
| Bowtie2 | Version not recorded |
| Nextflow | Version not recorded |

## Commands
All commands were run on the CGR Liverpool server on node ada26

### Obtain eukaryotic gut pathogen genomes
```
conda activate ~/envs/chos11/ncbi_datasets
# Get datasets version
echo -en "NCBI datasets,"$(datasets --version | head -n 1 | cut -f3 -d ' ')"\n" > datasets.version

mkdir -p gut_eukaryotes
cd gut_eukaryotes

while read -r species acc; do
    echo "Downloading $species ($acc)"

    datasets download genome accession "$acc" \
        --include genome \
        --filename "${species}.zip"

    unzip -p "${species}.zip" \
        "ncbi_dataset/data/${acc}/*_genomic.fna" \
        > "${species}.fna"

    # Remove zip after successful extraction
    if [[ -s "${species}.fna" ]]; then
        rm "${species}.zip"
    else
        echo "ERROR: No FASTA extracted for $species" >&2
    fi

done <<'EOF'
Cryptosporidium_parvum GCA_015245375.1
Cryptosporidium_hominis GCA_000006425.2
Giardia_duodenalis GCA_000002435.2
Entamoeba_histolytica GCA_000208925.2
Cyclospora_cayetanensis GCA_002019475.1
Blastocystis_sp_ST7 GCA_000151665.1
Ascaris_lumbricoides GCA_015227635.1
Trichuris_trichiura GCA_000613005.1
Strongyloides_stercoralis GCA_029582065.1
Necator_americanus GCA_031761385.1
Ancylostoma_ceylanicum GCA_000688135.1
Taenia_saginata GCA_001693075.2
Enterocytozoon_bieneusi GCA_000209485.1
EOF 
```

### Get host
```
cd host/
ln -s /pub58/sam/refs/Homo_sapiens/GRCh38/NCBI/GCF_000001405.40_GRCh38.p14_genomic.fna
cd ..
```

### Run workflow
This generates a set of reads (10x depth) of each pathogen genome and the host. It then runs Hostile and Hocort host removal on the combined dataset
```
# Check software versions of tools used in the workflow
conda activate /pub58/sam/envs/chos11/hostile
echo -en "hostile,"$(hostile --version)"\n" > hostile.version
echo "bowtie2,$(bowtie2 --version | head -n 1 | awk '{print $3}')" > bowtie2.version
conda deactivate
conda activate /pub58/sam/envs/chos11/hocort/
echo -en "hocort,"$(hocort --version | head -n 1 | cut -f2 -d ' ')"\n" > hocort.version
conda deactivate
conda activate /pub58/sam/envs/chos11/insilicoseq
echo -en "InsilicoSeq,"$(iss --version | head -n 1 | cut -f3 -d ' ')"\n" > insilicoseq.version
echo -en "nextflow,"$(nextflow -v | head -n 1 | cut -f3 -d ' ')"\n" > nextflow.version

# Run
nextflow run main.v2.nf \
  --fasta_dir ./gut_eukaryotes \
  --out_dir ./simulated \
  --target_depth 10 \
  --cpus 64 \
  -resume
```

### Get read counts for host-depleted and host-associated sets
```bash
# Hostile
zcat simulated/hostile/host_negative/mixed_R1.clean_1.fastq.gz | awk 'NR%4==1' | cut -f1-2 -d '_' | sort | uniq -c > hostile.negative.tally &
zcat simulated/hostile/host_positive/mixed_R1.clean_1.fastq.gz | awk 'NR%4==1' | cut -f1-2 -d '_' | sort | uniq -c > hostile.positive.tally &
wait

awk '                                                                     
    NR==FNR { neg[$2]=$1; species[$2]=1; next }
    { pos[$2]=$1; species[$2]=1 }
    END {
        printf "%-35s %12s %12s\n", "Species", "Negative (%)", "Positive (%)"
        for (s in species) {
            total = neg[s] + pos[s]
            if (total > 0)
                printf "%-35s %12.4f %12.4f\n", s, 100*neg[s]/total, 100*pos[s]/total
        }
    }
' hostile.negative.tally hostile.positive.tally > hostile.tally.txt


# Hocort
zcat simulated/hocort/hocort_negative_R1.fastq.gz | awk 'NR%4==1' | cut -f1-2 -d '_' | sort | uniq -c > hocort.negative.tally &
zcat simulated/hocort/hocort_positive_R1.fastq.gz | awk 'NR%4==1' | cut -f1-2 -d '_' | sort | uniq -c > hocort.positive.tally &

awk '                                                                     
    NR==FNR { neg[$2]=$1; species[$2]=1; next }
    { pos[$2]=$1; species[$2]=1 }
    END {
        printf "%-35s %12s %12s\n", "Species", "Negative (%)", "Positive (%)"
        for (s in species) {
            total = neg[s] + pos[s]
            if (total > 0)
                printf "%-35s %12.4f %12.4f\n", s, 100*neg[s]/total, 100*pos[s]/total
        }
    }
' hocort.negative.tally hocort.positive.tally > hocort.tally.txt
```

```
cat hostile.tally.txt
# Species                             Negative (%) Positive (%)
# @Necator_americanus                      99.9910       0.0090
# @Cryptosporidium_parvum                  99.9832       0.0168
# @Blastocystis_sp                         99.9254       0.0746
# @Entamoeba_histolytica                   99.9951       0.0049
# @Cryptosporidium_hominis                 99.9761       0.0239
# @Giardia_duodenalis                      99.9995       0.0005
# @Enterocytozoon_bieneusi                 99.9837       0.0163
# @Trichuris_trichiura                     99.9917       0.0083
# @Homo_sapiens                             4.8867      95.1133
# @Taenia_saginata                         99.9333       0.0667
# @Strongyloides_stercoralis               99.9976       0.0024
# @Ancylostoma_ceylanicum                  99.9947       0.0053
# @Ascaris_lumbricoides                    99.9784       0.0216
# @Cyclospora_cayetanensis                 99.9997       0.0003
```

* The above results show that both tools deplete the majority of host reads, but do not deplete the eukaryotic pathogen reads
* Interestingly, over 4% of host reads remain after host removal
  * Suspect this is due to generation of reads that are not reliably mappable 
* Unexpectedly, the output of hocort is identical. However, on inspection this is due to them both utilising the same aligner, bowtie2, with the same parameters

### Run Kraken2 on host-depleted set
As we know that the above depletion test does not remove the eukaryotic pathogens, we will test whether the reason we don't see them in the taxonomic profile data is due to under-representation in standard databases. For this we will use the Standard plus PFP database, using the Hostile-depleted data

```bash
conda activate ~/envs/chos11/kraken2

# Get version
echo -en "kraken2,"$(kraken2 --version | head -n 1 | cut -f3 -d ' ')"\n" > kraken2.version

kraken2 \
  --use-names \
  --db /pub7/kraken2-PlusPFP_030326 \
  --paired \
  --gzip-compressed \
  --threads 192 \
  --report kraken2.report \
  --output kraken2.output.named \
  simulated/hostile/host_negative/mixed_R1.clean_1.fastq.gz \
  simulated/hostile/host_negative/mixed_R2.clean_2.fastq.gz

# 46948815 sequences (14178.54 Mbp) processed in 165.683s (17001.9 Kseq/m, 5134.57 Mbp/m).
#   4670303 sequences classified (9.95%)
#   42278512 sequences unclassified (90.05%)

# Obtain reads assigned per taxa
awk -F'\t' '
BEGIN {OFS="\t"}
{
    split($2,a,"_")
    species=a[1]"_"a[2]
    tot[species][$3]++
}
END {
    for (species in tot)
        for (taxon in tot[species])
            print taxon,tot[species][taxon] > species".abundance.tsv"
}' kraken2.output.named
```

* Assessing all of the abundance.tsv files, it's clear that
  * Overall classification: Kraken2 classified 9.95% of reads (4.67 million pairs), leaving 90.05% unclassified (42.28 million pairs).
  * Pathogen detection: Only 2 of 13 eukaryotic pathogen species were identified under their expected specCies names.
  * Giardia duodenalis: 389,168 reads assigned (approximately 96.66% of expected reads).
  * Cryptosporidium: 594,602 reads assigned to C. parvum (approximately 98.91% of combined C. parvum and C. hominis reads), suggesting Kraken2 cannot distinguish the two species in this dataset.
  * Human reads: 969,167 assigned to Homo sapiens (approximately 18.04% of the remaining human reads).
  * Unexpected assignments: 4.03% of reads were classified as Viridiplantae, despite no plant genomes being included in the simulation.
  * Caveat: These percentages are inferred from aggregate counts. Comparing Kraken2 assignments against the original species-prefixed read IDs is necessary to determine actual classification accuracy and misclassification rates. But this gives a good indication that we're losing assignments at the Kraken2 stage
  
### Run Kraken2 on custom database
We will construct a custom Kraken2 database containing the human and eukaryotic pathogen genomes used in the simulations, then reprofile the reads. Since the reads were simulated directly from these genomes, we would expect very high classification rates and accurate taxonomic assignments. If this is not observed, it could indicate an issue with Kraken2's classification approach or our database construction. Conversely, if classification improves substantially, this would confirm that the poor performance observed with the standard PlusPFP database is primarily due to incomplete reference representation rather than a fundamental limitation of Kraken2.
```bash
# Set up database directory
DB=kraken2_gut_eukaryotes
mkdir -p $DB/taxonomy

# Obtain taxonomy files
cd $DB/taxonomy
curl -fLO https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
curl -fLO https://ftp.ncbi.nlm.nih.gov/pub/accession2taxid/nucl_gb.accession2taxid.gz
curl -fLO https://ftp.ncbi.nlm.nih.gov/pubaccession2taxid/nucl_wgs.accession2taxid.gz
tar -zxvf taxdump.tar.gz
gunzip nucl_*.accession2taxid.gz
cd -

# Add genomes to library
for f in gut_eukaryotes/*.fna; 
do
  kraken2-build --add-to-library $f --db $DB
done

# Build database
kraken2-build --build --threads 192 --db $DB

# Classify reads
kraken2 \
  --db ./kraken2_gut_eukaryotes/ \
  --paired \
  --gzip-compressed \
  --threads 192 \
  --report kraken2.patho.report \
  --output kraken2.patho.output \
  simulated/hostile/host_negative/mixed_R1.clean_1.fastq.gz \
  simulated/hostile/host_negative/mixed_R2.clean_2.fastq.gz

# 46948815 sequences (14178.54 Mbp) processed in 160.669s (17532.5 Kseq/m, 5294.81 Mbp/m).
#   41206858 sequences classified (87.77%)
#   5741957 sequences unclassified (12.23%)

# Obtain tallies of correct/incorrect hits
conda activate /pub58/sam/envs/chos11/pandas
# Get Pandas version
python -c "import pandas as pd; print "pandas,(pd.__version__)" 

./tabulate_hits.py 
#                            On target  Ambiguous  Unassigned   Human
# Species                                                            
# Ancylostoma_ceylanicum       98.0966     0.0064      1.8395  0.0576
# Ascaris_lumbricoides         99.4890     0.0384      0.4288  0.0438
# Blastocystis_sp              99.6683     0.0037      0.3232  0.0048
# Cryptosporidium_hominis      98.1166     1.7504      0.1228  0.0101
# Cryptosporidium_parvum       98.3367     1.4992      0.1457  0.0184
# Cyclospora_cayetanensis      99.8856     0.0090      0.0859  0.0195
# Entamoeba_histolytica        98.1605     0.0305      1.7541  0.0549
# Enterocytozoon_bieneusi      99.4653     0.0412      0.4772  0.0163
# Giardia_duodenalis           96.6414     0.0112      3.3474  0.0000
# Homo_sapiens                  0.0507     0.0001     99.9492  0.0000
# Necator_americanus           99.7055     0.1160      0.1055  0.0730
# Strongyloides_stercoralis    96.6671     0.0725      3.1730  0.0874
# Taenia_saginata              99.0627     0.0064      0.9256  0.0053
# Trichuris_trichiura          99.9971     0.0008      0.0021  0.0000
```

* Excellent classification: All 13 eukaryotic pathogens achieved 96.6–100% correct species-level assignment using the custom Kraken2 database.
* Database completeness: The substantial improvement over PlusPFP suggests that missing reference genomes were the main limitation.
* Lowest classification rates: *Giardia duodenalis* and *Strongyloides stercoralis* (~96.6%), primarily due to unclassified reads.
* Cryptosporidium: Around 1.5–1.75% of reads were assigned to other taxa or higher taxonomic ranks, likely reflecting similarity between species.
* Human misclassification: Very low (0–0.09%) across pathogen-derived reads.
* Residual human reads: Almost entirely unclassified (99.95%), potentially because they represent reads that already escaped host removal and are therefore not mappable reads.
* Caveat: These are best-case results, as the simulated reads originate from the same genomes used to construct the database. 

### Display software versions
```
cat *.version
# bowtie2,2.5.4
# NCBI datasets,18.19.0
# hocort,1.2.2
# hostile,2.0.2
# InsilicoSeq,2.0.1
# kraken2,2.1.3
# nextflow,22.04.5.5708
# pandas,1.4.3
```

