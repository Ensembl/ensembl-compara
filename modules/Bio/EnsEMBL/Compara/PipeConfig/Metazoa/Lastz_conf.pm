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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Lastz_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Lastz_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id_list "[9515,9516,9517]"

=head1 DESCRIPTION

This is a Metazoa configuration file for LastZ pipeline. Please, refer to the
parent class for further information.

Selected funnel analyses are blocked on pipeline initialisation.
These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::Lastz_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');


sub default_options {
my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'division'  => 'metazoa',
        # healthcheck
        'do_compare_to_previous_db' => 0,
        # Net
        'bidirectional' => 1,
    };
}


sub tweak_analyses {
    my $self = shift;
    $self->SUPER::tweak_analyses(@_);
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'alignment_nets'            => '2Gb_job',
        'create_alignment_nets_jobs'=> '2Gb_job',
        'create_alignment_chains_jobs'  => '4Gb_job',
        'create_filter_duplicates_jobs'     => '2Gb_24_hour_job',
        'create_pair_aligner_jobs'  => '2Gb_job',
        'populate_new_database' => '8Gb_job',
        'parse_pair_aligner_conf' => '4Gb_job',
        $self->o('pair_aligner_logic_name') => '4Gb_24_hour_job',
        $self->o('pair_aligner_logic_name')."_himem" => '8Gb_24_hour_job',
    );

    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }

    # Block unguarded funnel analyses; to be unblocked as needed during pipeline execution.
    my @unguarded_funnel_analyses = (
        'check_no_partial_gabs',
        'update_max_alignment_length_after_FD',
        'create_alignment_nets_jobs',
        'remove_inconsistencies_after_chain',
        'remove_inconsistencies_after_net',
        'remove_inconsistencies_after_net_fd',
        'run_healthchecks',
        'pairaligner_stats',
        'coding_exon_stats_summary',
    );

    foreach my $logic_name (@unguarded_funnel_analyses) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }

}


1;
