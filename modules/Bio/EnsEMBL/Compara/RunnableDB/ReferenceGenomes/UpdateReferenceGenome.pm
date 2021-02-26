
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

Bio::EnsEMBL::Compara::RunnableDB::ReferenceGenomes::UpdateReferenceGenome

=head1 DESCRIPTION

This RunnableDB is a wrapper around update_reference_genome.pl

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReferenceGenomes::UpdateReferenceGenome;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::ReferenceDatabase;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'force' => 0,
    };
}

sub write_output{
    my $self = shift @_;

    my ($new_ref_gdb, $comp_gdbs, $dnafrag_count) = @{ Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::update_reference_genome($self->compara_dba(), $self->param('species_name'), -FORCE => $self->param('force') )};
    $self->dataflow_output_id( {genome_db_id => $new_ref_gdb->dbID}, 1 );
}

1;
