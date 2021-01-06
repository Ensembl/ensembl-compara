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

Bio::EnsEMBL::Compara::RunnableDB::GetComparaDBName

=head1 DESCRIPTION

Takes a compara registry alias to output the corresponding database name.
Also accepts a specified branch number as branch_num or defaults to 1.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GetComparaDBName;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'branch_num'    => 1,
    };
}

sub write_output {
    my $self = shift;

    my $dbname = $self->compara_dba->dbc->dbname;
    $self->dataflow_output_id( {dbname => [$dbname]}, $self->param('branch_num') );
}

1;
