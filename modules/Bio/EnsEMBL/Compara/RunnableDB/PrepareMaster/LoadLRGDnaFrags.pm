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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::LoadLRGDnaFrags

=head1 SYNOPSIS

Runnable wrapper for Bio::EnsEMBL::Compara::Utils::MasterDatabase::load_lrgs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::LoadLRGDnaFrags;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'param'   => undef,
    }
}

sub fetch_input {
	my $self = shift;

  my $human_gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly('homo_sapiens');
  Bio::EnsEMBL::Compara::Utils::MasterDatabase::load_lrgs($self->compara_dba, $human_gdb);
}

1;
