=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a $rows = copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CopyDnaFragsByGenomeDB

=head1 DESCRIPTION

This module imports all the dnafrags for a given GenomeDB.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CopyDnaFragsByGenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $genome_db_id = $self->param_required('genome_db_id');

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $from_dbc = $master_dba->dbc;
    my $to_dbc = $self->compara_dba->dbc;
    my $input_query = "SELECT * FROM dnafrag WHERE genome_db_id = $genome_db_id";
    copy_data($from_dbc, $to_dbc, 'dnafrag', $input_query, undef, 'skip_disable_vars', $self->debug);
}


1;
