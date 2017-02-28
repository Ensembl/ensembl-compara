# Deprecated methods scheduled for deletion

## Methods removed in favour of toString() in Ensembl 88

* `Member::print_member()`
* `Homology::print_homology()`
* `GenomicAlign::_print()`
* `GenomicAlignBlock::_print()`
* `ConservationScore::_print()`

## Miscellaneous, to be removed in Ensembl 88

* `NCBITaxon::binomial()`
* `SpeciesTree::species_tree()`
* `GenomeDBAdaptor::fetch_all_by_low_coverage()`
* `GenomeDBAdaptor::fetch_all_by_taxon_id_assembly()`
* `GenomeDBAdaptor::fetch_by_taxon_id()`
* `GeneMemberAdaptor::load_all_from_seq_members()`

## Miscellaneous, to be removed in Ensembl 89

* `MethodLinkSpeciesSet::species_set_obj()`
* `SequenceAdaptor::fetch_by_dbIDs()`
* `SyntenyRegion::regions()`

## Taxonomy methods, to be removed in Ensembl 91

* `NCBITaxon::ensembl_alias_name()`
* `NCBITaxon::common_name()`

## DnaFrag methods, to be removed in Ensembl 91

* `DnaFrag::isMT()`
* `DnaFrag::dna_type()`
* `DnaFragAdaptor::is_already_stored()`

## \*MemberAdaptor methods, to be removed in Ensembl 91

* `GeneMemberAdaptor::fetch_all_by_source_Iterator()`
* `GeneMemberAdaptor::fetch_all_Iterator()`
* `SeqMemberAdaptor::fetch_all_by_source_Iterator()`
* `SeqMemberAdaptor::fetch_all_Iterator()`
* `SeqMemberAdaptor::update_sequence()`

## Miscellaneous, to be removed in Ensembl 91

* `MethodLinkSpeciesSet::get_common_classification()`

# Deprecated methods not yet scheduled for deletion

* `GenomicAlignTree::genomic_align_array()`
* `GenomicAlignTree::get_all_GenomicAligns()`

