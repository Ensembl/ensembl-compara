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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions

=head1 DESCRIPTION

This pipeline-part updates the gene- and seq-member names and descriptions.
This needs to be run if these have changed since the members were loaded,
for instance if they have been projected following our new orthology
predictions.

=head1 USAGE

=head2 eHive configuration

This pipeline assumes the param_stack is turned on. There is 1 stream
of jobs per species, so you will have to set 'update_capacity' not to
overload the database.

Jobs usually take 500MB of memory and expect the 500Mb_job resource-class
to be defined.

=head2 Seeding

This pipeline has to be seeded with a single job that defines the database
to work on via the "compara_db" parameter.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions;

use strict;
use warnings;


sub pipeline_analyses_member_names_descriptions {
    my ($self) = @_;
    return [

        {
            -logic_name => 'species_update_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into => {
                2   => [ 'update_member_display_labels' ],
            },
        },

        {
            -logic_name => 'update_member_display_labels',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -analysis_capacity => $self->o('update_capacity'),
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'display_label',
                'source_name'             => 'ENSEMBLGENE',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -flow_into => [ 'update_seq_member_display_labels' ],
            -rc_name => '500Mb_job',
        },

        {
            -logic_name => 'update_seq_member_display_labels',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -analysis_capacity => $self->o('update_capacity'),
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'display_label',
                'source_name'             => 'ENSEMBLPEP',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -flow_into => [ 'update_member_descriptions' ],
            -rc_name => '500Mb_job',
        },

        {
            -logic_name => 'update_member_descriptions',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::MemberDisplayLabelUpdater',
            -analysis_capacity => $self->o('update_capacity'),
            -parameters => {
                'die_if_no_core_adaptor'  => 1,
                'replace'                 => 1,
                'mode'                    => 'description',
                'genome_db_ids'           => [ '#genome_db_id#' ],
            },
            -rc_name => '500Mb_job',
        },

    ];
}

1;


