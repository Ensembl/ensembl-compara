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

Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers

=head1 DESCRIPTION

The PipeConfig file for the pipeline that loads the ncbi tables and core
genome_dbs

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub pipeline_analyses_copy_ncbi_and_core_genome_db {
    my ($self) = @_;

    my %hc_analysis_params = (
        -analysis_capacity  => 150,
        -priority           => -10,
        -batch_size         => 20,
    );

    return [
    #--------------------NCBI table copying------------------#
        {   -logic_name => 'copy_ncbi_tables_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],
                'column_names' => [ 'table' ],
            },
            -flow_into  => {
                '2->A' => [ 'copy_ncbi_table' ],
                'A->1' => [ 'locate_and_add_genomes' ],
            },
        },

        {   -logic_name    => 'copy_ncbi_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#ncbi_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },
    #--------------------Update pipeline_db as if master_db------------------#
        {   -logic_name    => 'locate_and_add_genomes',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::AddRapidSpecies',
            -hive_capacity => 10,
            -rc_name       => '16Gb_job',
            -flow_into     => {
                '2->A' => [
                    { 'load_fresh_members_from_db' => { 'genome_db_id' => '#genome_db_id#' } },
                ],
                'A->1' => [ 'hc_members_globally' ],
            },
        },
    #--------------------Query genome member loading------------------#
        {   -logic_name    => 'load_fresh_members_from_db',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters    => {
                'include_reference'           => $self->o('include_reference'),
                'include_nonreference'        => $self->o('include_nonreference'),
                'include_patches'             => $self->o('include_patches'),
                'store_coding'                => $self->o('store_coding'),
                'store_ncrna'                 => $self->o('store_ncrna'),
                'store_others'                => $self->o('store_others'),
                'store_exon_coordinates'      => $self->o('store_exon_coordinates'),
                'store_related_pep_sequences' => $self->o('store_related_pep_sequences'),
                'compara_db'                  => $self->o('compara_db'),
                'master_db'                   => $self->o('compara_db'),
                'skip_dna'                    => $self->o('skip_dna'),
            },
            -hive_capacity => 10,
            -rc_name       => '4Gb_job',
            -flow_into     => ['hc_members_per_genome'],
        },
    #--------------------Healthcheck members------------------#
        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                'mode'                          => 'members_per_genome',
                'allow_ambiguity_codes'         => $self->o('allow_ambiguity_codes'),
                'only_canonical'                => $self->o('only_canonical'),
                'allow_missing_cds_seqs'        => $self->o('allow_missing_cds_seqs'),
                'allow_missing_coordinates'     => $self->o('allow_missing_coordinates'),
                'allow_missing_exon_boundaries' => $self->o('allow_missing_exon_boundaries'),
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode   => 'members_globally',
            },
        },

    ];
}

1;
