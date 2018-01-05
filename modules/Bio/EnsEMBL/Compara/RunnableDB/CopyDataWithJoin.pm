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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin

=head1 DESCRIPTION

Simple wrapper around Utils::CopyData::copy_data that can copy large
chunks of data much faster than eHive's dataflow-into-a-table mechanism.

=over

=item inputquery

A SQL query to feed the transfer. It is executed in eHive's "data" source,
which is set by the parameter "db_conn", and otherwise defaults to the
current database.

=item table

The name of the table to store the data in. The Runnable assumes that the
input query fills all the columns.

=back

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift @_;
    copy_data($self->data_dbc, $self->compara_dba->dbc, $self->param_required('table'), $self->param_required('inputquery'));
}

1;
