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

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::SliceFactory

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::SliceFactory;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Data::Dumper;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 my $msa_genome_id = $self->param('msa_mlssid_and_reference_species')->{$self->param('msa_mlssid')};
 my $genome_db_a = $self->compara_dba->get_adaptor("GenomeDB");
 my $ref_genome_db = $genome_db_a->fetch_by_dbID($msa_genome_id);
 my $ref_genome_db_name = $ref_genome_db->name;
 Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('core_dbs') } );
 my $slice_a = Bio::EnsEMBL::Registry->get_adaptor( "$ref_genome_db_name", "core", "Slice");
 my @Slices;
 my $coord_system_name = $self->param('coord_system_name') || "toplevel";
 foreach my $slice(@{ $slice_a->fetch_all("$coord_system_name") }){
  push(@Slices, { 'slice_name' => $slice->seq_region_name, 'ref_species_name' => $ref_genome_db_name, 'msa_mlssid' => $self->param('msa_mlssid') });
 }
 $self->param('ref_slices', \@Slices);
}

sub write_output {
 my $self = shift @_;
 $self->dataflow_output_id($self->param('ref_slices'), 2);
}


1;

