=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector

=head1 DESCRIPTION

Utility methods for collecting taxonomic ranks and matching to taxonomic references

=cut

package Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector;

use strict;
use warnings;
use base qw(Exporter);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use List::MoreUtils 'all';
use List::Util;
use Data::Dumper;

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    collect_reference_classification
    match_query_to_reference_taxonomy
    collect_species_set_dirs
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);

=head2 collect_reference_classification

    Collect reference ncbi taxonomic classifications by species_set.
    Returns array of species_set names.
    E.g. my \@taxon_clade = collect_reference_classification($compara_dba);

=cut

sub collect_reference_classification {
    my $master_db = shift;

    my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($master_db);
    my $ss_adaptor = $dba->get_SpeciesSetAdaptor;
    my $ss_names   = $ss_adaptor->fetch_all;
    my @ss_names   = map {$_->name} @$ss_names;

    return \@ss_names;
}

=head2 match_query_to_reference_taxonomy

    Match starting from lowest taxonomic rank climbing, returning string variable at first match.
    Returns undef if no match found.
    E.g. my $ref_clade = match_query_to_reference_taxonomy($compara_dba, $genome_db);

=cut

sub match_query_to_reference_taxonomy {
    my ($self, $genome_db, $master_dba, $taxon_list) = (@_);

    throw ("taxon_list and master_dba are mutually exclusive, pick one") if $taxon_list && $master_dba;
    throw ("Either taxon_list or master_dba need to be provided") if (all { undef } $taxon_list, $master_dba);

    my @taxon_list = $taxon_list ? @$taxon_list : @{collect_reference_classification($master_dba)};
    my $taxon_dba  = $self->compara_dba->get_NCBITaxonAdaptor;
    my $parent     = $taxon_dba->fetch_by_dbID($genome_db->taxon_id)->parent;

    while ( $parent->name ne "root" ) {
        if ( grep { lc($parent->name) eq $_ } @taxon_list ) {
            return lc($parent->name);
        }
        else {
            $parent = $parent->parent;
        }
    }

    return undef;
}

=head2 collect_species_set_dirs

    Collect list of dir_revhash paths for all genomes in taxonomic clade by species_set.
    Does not return absolute paths, only the paths starting at the reverse hash of gdb, so
    will require appending to dump path dir or working dir etc.
    E.g. my $dir_paths = collect_species_set_dirs($compara_dba, $ncbi_taxa_name);

=cut

sub collect_species_set_dirs {
    my ($master_db, $taxa_name) = (@_);

    my $dba          = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($master_db);
    my $ss_adaptor   = $dba->get_SpeciesSetAdaptor;
    my $species_set  = $ss_adaptor->fetch_all_by_name($taxa_name);
    my $genome_dbs   = $species_set->genome_dbs;
    my @genome_files;

    foreach my $gdb ( @$genome_dbs ) {
        my $ref_dmnd    = $gdb->get_dmnd_helper();
        my $ref_fasta   = $gdb->dir_revhash();
        my $ref_splitfa = $gdb->get_splitfa_helper();
        push @genome_files => { 'ref_gdb' => $gdb, 'ref_fa' => $ref_fasta, 'ref_dmnd' => $ref_dmnd, 'ref_splitfa' => $ref_splitfa };
    }
    my @sorted_genome_files = sort { $a->{ref_gdb} <=> $b->{ref_gdb} } @genome_files;
    return \@sorted_genome_files;
}

1;
