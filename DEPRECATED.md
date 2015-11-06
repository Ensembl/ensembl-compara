# Deprecated methods scheduled for deletion

## In Ensembl 84

### Obsolete since the redesign of member sequences
* `AlignedMember::alignment_string()`
* `AlignedMember::alignment_string_bounded()`
* `AlignedMember::cdna_alignment_string()`
* `MemberSet::print_sequences_to_fasta()`
* `SeqMember::get_exon_bounded_sequence()`
* `SeqMember::get_other_sequence()`
* `SeqMember::sequence_cds()`
* `SeqMember::sequence_exon_bounded()`
* `SeqMember::sequence_exon_cased()`

### Obsolete since the redesign of the species-tree reconciliation
* `GeneTreeNode::get_value_for_tag('taxon_id')`
* `GeneTreeNode::get_value_for_tag('taxon_name')`
* `Homology::node_id()`
* `Homology::ancestor_tree_node_id()`
* `Homology::tree_node_id()`
* `Homology::subtype()`
* `Homology::taxonomy_alias()`

### Obsolete since the redesign of member objects
* `Member::chr_name()`
* `Member::chr_start()`
* `Member::chr_end()`
* `Member::chr_strand()`
* `GeneMember::member_id()`
* `GeneMember::get_all_peptide_Members()`
* `GeneMember::get_canonical_Member()`
* `GeneMember::get_canonical_peptide_Member()`
* `GeneMember::get_canonical_transcript_Member()`
* `SeqMember::member_id()`
* `MemberAdaptor::fetch_by_source_stable_id()`
* `MemberAdaptor::fetch_all_by_source_stable_ids()`
* `MemberAdaptor::fetch_all_by_source_genome_db_id()`
* `SeqMemberAdaptor::fetch_all_by_gene_member_id()`
* `SeqMemberAdaptor::fetch_all_canonical_by_source_genome_db_id()`
* `SeqMemberAdaptor::fetch_canonical_member_for_gene_member_id()`
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

