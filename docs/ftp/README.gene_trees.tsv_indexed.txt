Directory 'tsv/ensembl-compara/homologies' and its subdirectories contain
tab-separated value (TSV) dumps of homologies inferred on gene trees.

All homology TSV dump files have the same naming convention and fields, as follows.

Compara.{release}.{protein|ncrna}_{species_collection}.homologies.tsv.gz
  Each homology between a pair of genes is represented
  on one tab-delimited line, with the following fields:
    gene_stable_id : gene stable_id of the first homologous gene
    protein_stable_id : sequence stable_id of the first homologous gene (may be a protein or transcript stable_id, depending on whether the gene is protein-coding)
    species : name of the genome containing the first homologous gene
    identity : identity between homologous sequences, expressed as a percentage of the length of the representative sequence of the first homologous gene
    homology_type : homology type and cardinality (e.g. 'ortholog_one2one')
    homology_gene_stable_id : gene stable_id of the second homologous gene
    homology_protein_stable_id : sequence stable_id of the second homologous gene (may be a protein or transcript stable_id)
    homology_species : name of the genome containing the second homologous gene
    homology_identity : identity between homologous sequences, expressed as a percentage of the length of the representative sequence of the second homologous gene
    dn : non-synonymous mutation rate (currently unused)
    ds : synonymous mutation rate (currently unused)
    goc_score : gene order conservation (GOC) score of the homology
    wga_coverage : whole genome alignment (WGA) coverage of the homology
    is_high_confidence : whether this is considered a 'high-confidence' homology
    homology_id : unique internal ID of the homology
  Note that within these files, the order of the first and second homologous genes within each row
  is arbitrary, and should not be interpreted as conferring any special status on one or the other.
  Both genes are co-equal participants in a homology relationship.

Within each subdirectory of 'tsv/ensembl-compara/homologies' named for a specific genome, each
genome-specific homology TSV file contains all available homologies for the given genome in a
specific gene-tree species collection (e.g. 'default') and member type (e.g. 'protein').

For those who need access to homologies involving a pair of genomes, genome-specific homology TSV files
have been tabix-indexed on the 'homology_species' column. So for example, the following command could be
used to retrieve orthologies between the 'mus_musculus' and 'homo_sapiens' reference genomes:

tabix -h https://ftp.ensembl.org/pub/current_tsv/ensembl-compara/homologies/mus_musculus/Compara.116.protein_default.homologies.tsv.gz homo_sapiens

For those who need access to homologies involving most or all genomes in a specific gene-tree
species collection, concatenated homology TSV dump files are available at the top level of
directory 'tsv/ensembl-compara/homologies'.

Please consult the file 'README.gene_trees.tsv_dump.txt'
for more information on concatenated homology TSV files.
