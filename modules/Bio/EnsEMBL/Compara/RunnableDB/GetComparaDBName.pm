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

sub fetch_input {
    my $self = shift;

    my $compara_dba = $self->compara_dba;
    my @dbname      = $compara_dba->dbc->dbname;
    my $branch_num  = $self->param('branch_num') // 1;

    $self->param( 'dbname', \@dbname );
    $self->param( 'branch_num', $branch_num );
}

sub write_output {
    my $self = shift;

    $self->dataflow_output_id( {dbname => $self->param('dbname')}, $self->param('branch_num') );
}

1;
