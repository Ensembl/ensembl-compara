> This file contains the list of methods deprecated in the Ensembl Compara
> API.  A method is deprecated when it is not functional any more
> (schema/data change) or has been replaced by a better one.  Backwards
> compatibility is provided whenever possible.  When a method is
> deprecated, a deprecation warning is thrown whenever the method is used.
> The warning also contains instructions on replacing the deprecated method
> and when it will be removed.

----

# Deprecated methods scheduled for deletion

## Methods removed in favour of toString() in Ensembl 88

* `GenomicAlign::_print()`
* `GenomicAlignBlock::_print()`
* `ConservationScore::_print()`

## Miscellaneous, to be removed in Ensembl 89

* `MethodLinkSpeciesSet::species_set_obj()`

## DnaFrag methods, to be removed in Ensembl 91

* `DnaFrag::isMT()`
* `DnaFrag::dna_type()`

## Taggable AUTOLOAD-ed methods, to be removed in Ensembl 94

* `Taggable::get_value_for_XXX()`
* `Taggable::get_all_values_for_XXX()`
* `Taggable::get_XXX_value()`

# Deprecated methods not yet scheduled for deletion

* `GenomicAlignTree::genomic_align_array()`
* `GenomicAlignTree::get_all_GenomicAligns()`

# Methods removed in previous versions of Ensembl

## Ensembl 92

* `Member::print_member()`
* `SyntenyRegion::regions()`

## Ensembl 91

* `Homology::print_homology()`
* `MethodLinkSpeciesSet::get_common_classification()`
* `NCBITaxon::binomial()`
* `NCBITaxon::ensembl_alias_name()`
* `NCBITaxon::common_name()`
* `DnaFragAdaptor::is_already_stored()`
* `GeneMemberAdaptor::fetch_all_by_source_Iterator()`
* `GeneMemberAdaptor::fetch_all_Iterator()`
* `GeneMemberAdaptor::load_all_from_seq_members()`
* `GenomeDBAdaptor::fetch_all_by_low_coverage()`
* `GenomeDBAdaptor::fetch_all_by_taxon_id_assembly()`
* `GenomeDBAdaptor::fetch_by_taxon_id()`
* `SeqMemberAdaptor::fetch_all_by_source_Iterator()`
* `SeqMemberAdaptor::fetch_all_Iterator()`
* `SeqMemberAdaptor::update_sequence()`
* `SequenceAdaptor::fetch_by_dbIDs()`

## Ensembl 89

* `SpeciesTree::species_tree()`

