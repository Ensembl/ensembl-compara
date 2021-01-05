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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::PatchMasterDB

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::PatchMasterDB;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;
    my $master_dba = $self->get_cached_compara_dba('master_db');

    my $dbc = $master_dba->dbc;
	my $connection_cmd = "mysql -h " . $dbc->host . ' -P ' . $dbc->port . ' -u ' . $dbc->user . ' -p' . $dbc->pass . ' ' . $dbc->dbname;

    # Apply all patches in order
    my $patch_names = $self->param_required('patch_names');
    my @patch_files = glob $patch_names;
    @patch_files = sort @patch_files;
    foreach my $patch ( @patch_files ) {
        my $patch_run = $self->run_command("$connection_cmd < $patch");
    }
}

1;
