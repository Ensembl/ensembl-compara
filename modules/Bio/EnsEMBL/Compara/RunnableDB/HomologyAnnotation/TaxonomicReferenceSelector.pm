=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::TaxonomicReferenceSelector

=head1 DESCRIPTION

Runnable to take an array of reference taxon groups as 'taxon_list' and genome_db_id
to select an appropriate species_set and output reference genomes.

=over

=item taxon_list
(Optional) Default lists the current divisions + Eukaryota and Chordata.

=item reference_db
(Mandatory) The alias/url of the master database containing references to look up the
most appropriate species_set of reference genomes.

=item genome_db_id
(Mandatory) The query genome_db_id in which we want to find the appropriate reference genome
for.

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::TaxonomicReferenceSelector;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'taxon_list' => qw(Eukaryota, Metazoa, Chordata, Vertebrata, Plants, Fungi, Bacteria, Protists),
    }
}

sub fetch_input {
    my $self = shift;

    my $ref_dba   = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param('reference_db') );
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID( $self->param_required('genome_db_id') );
    my $ref_taxa  =_collect_classification_match($genome_db);

    my $ref_ss   = $ref_dba->get_SpeciesSetAdaptor->fetch_all_by_name($ref_taxa);
    my $ref_gdbs = $ref_ss->genome_dbs();

    my @ref_gdb_ids = ( sort { $a->dbID() <=> $b->dbID() } @$ref_gdbs );
    $self->param('ref_gdb_ids', \@ref_gdb_ids);
    $self->dataflow_output_id( { 'ref_gdb_ids' => \@ref_gdb_ids } );
}

sub write_output {
    my $self = shift;

    my @ref_gdb_ids = @{self->param('ref_gdb_ids')};
    $self->dataflow_output_id( { 'ref_gdb_ids' => \@ref_gdb_ids }, 1 );
}

sub _collect_classification_match {
    my ($self, $genome_db) = shift @_;

    my @taxon_list = @{$self->param('taxon_list')};
    my $taxon_dba  = $self->compara_dba->get_NCBITaxonAdaptor;
    my $parent     = $taxon_dba->fetch_by_dbID($genome_db->taxon_id);

    foreach my $taxa_name ( @taxon_list ) {
        my @taxon_ids = @{ $taxon_dba->fetch_all_nodes_by_name($taxa_name.'%') }
        if ( any { $_ eq $parent->dbID } @taxon_ids ) {
            return $taxa_name;
        }
    }
    return undef;

}

1;
