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

Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::PopulateMaster

=head1 SYNOPSIS

Runs the script 'clone_core_database.pl' (located at 'ensembl-test/scripts/' by default)
over a given JSON configuration file with the regions of data to clone.

Requires several inputs:
    'clone_data_regions' : full path to the clone script 'clone_core_database.pl'
    'reg_conf'  : full path to the registry configuration file
    'dst_host'  : host name where the new core database will be created
    'dst_port'  : host port
    'json_file' : JSON configuration file with the regions of data to clone

The dataflow output writes the new core database's name into the accumulator named 'cloned_db'.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::RenameTestDatabase;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;
use File::Slurp;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
    }
}

sub fetch_input {
    my $self = shift;
    my $script = $self->require_executable('rename_db');
    my $reg_conf = $self->param_required('reg_conf');
    my $species = $self->param_required('species');
    #
    my $cloned_dbname = $self->param_required('cloned_dbname');
    #
    our $test_core_dbs;
    require $reg_conf;
    my ( $host, $prod_dbname ) = @{ $test_core_dbs->{$species} };
    my $port = get_port($host);
    #
    my $cmd = "$script $host-ensadmin $cloned_dbname $prod_dbname";
    $self->param('cmd', $cmd);
}

sub run {
    my $self = shift;
    $self->param('runCmd', $self->run_command($self->param_required('cmd'), {die_on_failure => 1}));
}

1;
