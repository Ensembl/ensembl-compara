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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CloneCoreRegions

=head1 SYNOPSIS

Runs the script 'clone_core_database.pl' (located at 'ensembl-test/scripts/' by
default) over a given JSON configuration file with the regions of data to clone.

Requires several inputs:
    'clone_core_db' : full path to the clone script 'clone_core_database.pl'
    'init_reg_conf' : full path to the initial registry configuration file
    'dst_host'      : host name where the new core database will be created
    'dst_port'      : host port
    'json_file'     : JSON configuration file with the regions of data to clone

The dataflow output writes the new core database's name into the accumulator
'cloned_db'.


=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CloneCoreRegions;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub fetch_input {
    my $self = shift;
    my $script         = $self->param_required('clone_core_db_exe');
    my $init_reg_conf  = $self->param_required('init_reg_conf');
    my $dst_host       = $self->param_required('dst_host');
    my $json_file_path = $self->param_required('json_file');
    my $cmd = "$script -registry $init_reg_conf \$(${dst_host}-ensadmin details script_dest_) -json $json_file_path";
    $self->param('cmd', $cmd);
}

sub write_output {
    my $self = shift;
    $self->SUPER::write_output();
    # NOTE: clone script prints to stderr by default
    my $output = $self->param('stderr');
    # The cloned database name is found in the printed information and starts
    # with the username
    my ( $dbname ) = ( $output =~ /(\Q$ENV{USER}\E[^\n']+)/ );
    $self->dataflow_output_id({'cloned_dbs' => $dbname}, 1);
}

1;
