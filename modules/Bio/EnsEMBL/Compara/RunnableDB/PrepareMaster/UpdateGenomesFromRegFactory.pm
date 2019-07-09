=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromRegFactory

=head1 SYNOPSIS

Returns the list of species/genomes to add to the master database from the core
databases in the registry file

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::UpdateGenomesFromRegFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Hive::Process');

sub fetch_input {
    my $self = shift;
    my $species_list = Bio::EnsEMBL::Registry->get_all_species();
    $self->param('species_to_update', $species_list);
}

sub write_output {
    my $self = shift;
    my @new_genomes_dataflow = map { {species_name => $_, force => 0} } @{ $self->param('species_to_update') };
    $self->dataflow_output_id(\@new_genomes_dataflow, 2);
}

1;
