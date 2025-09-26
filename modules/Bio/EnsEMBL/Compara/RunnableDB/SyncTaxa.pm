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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SyncTaxa

=head1 DESCRIPTION

This RunnableDB synchronises taxon_ids between the 'from_table'
and one or more 'to_tables', updating the latter so that their
taxon_id values are synchronised with those of the former.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SyncTaxa;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::NCBITaxa qw(sync_taxon_ids_by_genome_db_id);
use Bio::EnsEMBL::Utils::Scalar qw(wrap_array);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $from_table = $self->param_required('from_table');
    my $to_tables = $self->param_required('to_tables');
    my $genome_db_id = $self->param('genome_db_id');

    my $genome_db_ids = wrap_array($genome_db_id);
    foreach my $to_table (@{$to_tables}) {
        sync_taxon_ids_by_genome_db_id(
            $self->compara_dba,
            $from_table,
            $to_table,
            $genome_db_ids,
        );
    }
}


1;
