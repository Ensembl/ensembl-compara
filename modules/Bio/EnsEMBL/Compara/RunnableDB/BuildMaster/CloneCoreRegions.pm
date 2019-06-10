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

Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CloneCoreRegions

=head1 SYNOPSIS

Runs the script 'clone_core_database.pl' (located at 'ensembl-test/scripts/' by default)
over a given JSON configuration file with the regions of data to clone.

Requires several inputs:
    'clone_core_db' : full path to the clone script 'clone_core_database.pl'
    'reg_conf'      : full path to the registry configuration file
    'dst_host'      : host name where the new core database will be created
    'dst_port'      : host port
    'json_file'     : JSON configuration file with the regions of data to clone

The dataflow output writes the new core database's name into the accumulator named 'cloned_db'.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CloneCoreRegions;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;
use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
    }
}

sub fetch_input {
    my $self = shift;
    my $script = $self->require_executable('clone_core_db');
    my $reg_conf = $self->param_required('reg_conf');
    my $dst_host = $self->param_required('dst_host');
    my $dst_port = $self->param_required('dst_port');
    my $json_file_path = $self->param_required('json_file');
    my $cmd = "perl $script -registry $reg_conf -dest_host $dst_host -dest_port $dst_port -dest_user ensadmin -dest_pass $ENV{'ENSADMIN_PSW'} -json $json_file_path";
    $self->param('cmd', $cmd);
}

sub run {
    my $self = shift;
    $self->param('runCmd', $self->run_command($self->param_required('cmd'), {die_on_failure => 1}));
}

sub write_output {
    my $self = shift;
    my $json_file_path = $self->param('json_file');
    # Remove ".json" from JSON file name to get species name
    my $species = substr(basename($json_file_path), 0, -5);
    my $runCmd = $self->param_required('runCmd');
    # The clone script prints to stderr by default
    my $output = $runCmd->err;
    my ( $dbname ) = ( $output =~ /(\Q$ENV{USER}\E[^\n']+)/ );
    $self->dataflow_output_id({'cloned_dbs' => ($species => $dbname)}, 1);
}

1;
