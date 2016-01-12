# Deprecated methods scheduled for deletion

## In Ensembl 84

### Obsolete since the redesign of member sequences
* `AlignedMember::cdna_alignment_string()`

### Obsolete since the redesign of the species-tree reconciliation
* `GeneTreeNode::get_value_for_tag('taxon_id')`
* `GeneTreeNode::get_value_for_tag('taxon_name')`
* `Homology::node_id()`

### Obsolete since the redesign of member objects
* `MemberAdaptor::fetch_by_source_stable_id()`
* `FamilyAdaptor::fetch_all_by_Member()`
* `FamilyAdaptor::fetch_by_Member_source_stable_id()`

### Others
* `GenomeDB::short_name()`
* `GenomeDB::assembly_default()`


## In Ensembl 86
* `Member::print_member()`
* `Homology::print_homology()`
* `HomologyAdaptor::fetch_all_by_Member_paired_species()`
* `HomologyAdaptor::fetch_all_by_genome_pair()`

# Deprecated methods not yet scheduled for deletion

* `GenomicAlignTree::genomic_align_array()`
* `GenomicAlignTree::get_all_GenomicAligns()`

