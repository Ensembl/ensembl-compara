=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::GeneFactory

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::GeneFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Data::Dumper;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('core_dbs') } );
 my $ref_species_name = $self->param('ref_species_name');
 my $gene_a = Bio::EnsEMBL::Registry->get_adaptor( $ref_species_name, "core", "Gene"); 
 my $slice_a = Bio::EnsEMBL::Registry->get_adaptor( $self->param('ref_species_name'), "core", "Slice");
 my $coord_system_name = $self->param('coord_system_name') || "toplevel";
 my $slice_name = $self->param('slice_name');
 my $slice = $slice_a->fetch_by_region("$coord_system_name", "$slice_name");
 my $slice_iter = $gene_a->fetch_Iterator_by_Slice( $slice );
 my ($gene, @transcript_ids);
 while($gene = $slice_iter->next){
  push(@transcript_ids, { "ref_species_name" => $ref_species_name, "transcript_id" => $gene->canonical_transcript->stable_id, "msa_mlssid" => $self->param('msa_mlssid') });
 }
 $self->param('trans_ids', \@transcript_ids);
}

sub write_output {
 my $self = shift @_;
 $self->dataflow_output_id($self->param('trans_ids'), 2) if scalar @{ $self->param('trans_ids') };
}


1;
