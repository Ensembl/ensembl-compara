> This file contains the list of methods deprecated in the Ensembl Compara
> API.  A method is deprecated when it is not functional any more
> (schema/data change) or has been replaced by a better one.  Backwards
> compatibility is provided whenever possible.  When a method is
> deprecated, a deprecation warning is thrown whenever the method is used.
> The warning also contains instructions on replacing the deprecated method
> and when it will be removed.

----

# Deprecated methods scheduled for deletion

* `DBSQL::DnaFragAdaptor::fetch_all_by_GenomeDB_region()` in Ensembl 98

## get VariationFeatures for AlignSlice, to be removed in Ensembl 95 

* `AlignSlice::Slice::get_all_VariationFeatures_by_VariationSet`
* `AlignSlice::Slice::get_all_genotyped_VariationFeatures`

## Taggable AUTOLOAD-ed methods, to be removed in Ensembl 94

* `Taggable::get_value_for_XXX()`
* `Taggable::get_all_values_for_XXX()`
* `Taggable::get_XXX_value()`

# Deprecated methods not yet scheduled for deletion

* `GenomicAlignTree::genomic_align_array()`
* `GenomicAlignTree::get_all_GenomicAligns()`

# Methods removed in previous versions of Ensembl

## Ensembl 93

* `DnaFrag::isMT()`
* `DnaFrag::dna_type()`
* `MethodLinkSpeciesSet::species_set_obj()`

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

