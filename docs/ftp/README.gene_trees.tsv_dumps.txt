Directory 'tsv/ensembl-compara/homologies' contains tab-separated
value (TSV) dumps of homologies inferred on gene trees.

All homology TSV dump files have the same naming convention and fields, as follows.

Compara.{release}.{protein|ncrna}_{gene_tree_collection}.homologies.tsv.gz
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

The contents of these files differs depending on their location relative
to the directory 'tsv/ensembl-compara/homologies'.

Each homology TSV dump file at the top level in this directory contains the complete set of available
homologies for a given gene-tree collection (e.g. 'default') and member type (e.g. 'protein'). It is
recommended to download this complete homology TSV file if you need to access most or all of the
homologies in a gene-tree collection.

For those who need access to homologies for a subset of genomes in a gene-tree collection, genome-specific
homology TSV dump files are available within each (possibly nested) subdirectory named for a particular genome
(e.g. 'saccharomyces_cerevisiae').

NOTE: To eliminate redundancy, a genome-specific homology TSV file contains an arbitrary
subset of orthologies involving the given genome. To access all available orthologies between two genomes
(e.g. 'drosophila_melanogaster' and 'saccharomyces_cerevisiae'), you will need to download the genome-specific
files of both genomes (e.g. 'drosophila_melanogaster/Compara.116.protein_default.homologies.tsv.gz'
and 'saccharomyces_cerevisiae/Compara.116.protein_default.homologies.tsv.gz').
