
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

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::VerifyGenome

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to check that the dnafrags
of a GenomeDB match the slices of a Core database.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::VerifyGenome;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    my $species_name = $self->param_required('species_name');
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($species_name);

    my $output;
    my $dnafrags_match;
    {
        local *STDOUT;
        open (STDOUT, '>', \$output);
        $dnafrags_match = Bio::EnsEMBL::Compara::Utils::MasterDatabase::dnafrags_match_core_slices($genome_db);
    }
    unless ($dnafrags_match) {
        $self->die_no_retry("DnaFrags do not match core for $species_name\n$output\n");
    }
}

1;
