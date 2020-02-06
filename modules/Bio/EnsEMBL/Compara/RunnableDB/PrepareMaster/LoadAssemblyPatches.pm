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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::LoadAssemblyPatches

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::LoadAssemblyPatches;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
  my $genome_db  = $genome_db_adaptor->fetch_by_name_assembly($self->param_required('species_name'));

  $self->param('genome_db',  $genome_db);
}

sub write_output {
	my $self = shift;

  my $compara_dba = $self->compara_dba;
  my $genome_db   = $self->param('genome_db');
  my $report_file = $self->param_required('work_dir') . '/assembly_patches.' . $self->param_required('species_name') . '.txt';

  Bio::EnsEMBL::Compara::Utils::MasterDatabase::load_assembly_patches($compara_dba, $genome_db, $report_file);
}

1;
