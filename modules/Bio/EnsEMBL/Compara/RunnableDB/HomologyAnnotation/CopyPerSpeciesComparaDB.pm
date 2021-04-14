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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::CopyPerSpeciesComparaDB

=head1 DESCRIPTION

Runs the ensembl-compara/scripts/pipeline/populate_per_genome_database.pl
script.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::CopyPerSpeciesComparaDB;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub fetch_input {
    my $self = shift;

    my @table_list = @{ $self->param('table_list') };
    my @cmd;

    push @cmd, $self->param_required('program');
    push @cmd, '--pipeline_db', $self->dbc->url();
    push @cmd, '--compara_db', $self->param_required('per_species_db');
    push @cmd, '--tables', join(',', @table_list);
    push @cmd, '--genome_name', $self->param('genome_name') if $self->param('genome_name');
    push @cmd, '--copy_dna', unless $self->param('skip_dna');

    $self->param('cmd', \@cmd);

}

1;
