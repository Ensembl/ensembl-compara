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

Bio::EnsEMBL::Compara::RunnableDB::HAL::InitLoadCactus

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::InitLoadCactus;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::IDGenerator qw(initialise_id);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;


    my $mlss_id = $self->param_required('mlss_id');
    my $label = "genomic_align_${mlss_id}";
    my $first_id = ($mlss_id * 10**10) + 1;
    initialise_id($self->compara_dba->dbc, $label, $first_id);

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my @mlss_gdbs = grep { !$_->genome_component } @{$mlss->species_set->genome_dbs};
    my %mlss_gdb_name_to_id = map { $_->name => $_->dbID } @mlss_gdbs;

    my $ref_genome_name = $mlss->get_value_for_tag('reference_species');

    unless (defined $ref_genome_name) {
        $self->die_no_retry("MLSS $mlss_id lacks required tag 'reference_species'");
    }

    unless (exists $mlss_gdb_name_to_id{$ref_genome_name} && defined $mlss_gdb_name_to_id{$ref_genome_name}) {
        $self->die_no_retry("Reference genome ($ref_genome_name) of MLSS $mlss_id is not in its species set");
    }

    my @pending_ref_gdb_ids = ($mlss_gdb_name_to_id{$ref_genome_name});

    my $output_id = {
        'num_pending_ref_gdb_ids' => scalar(@pending_ref_gdb_ids),
        'pending_ref_gdb_ids' => \@pending_ref_gdb_ids,
    };

    $self->dataflow_output_id($output_id, 2);
}


1;
