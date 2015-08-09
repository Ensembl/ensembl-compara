=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf.

=head1 DESCRIPTION

The PipeConfig file for a pipeline that should for data integrity of a gene-tree / homology table.

=head1 SYNOPSIS

It can be entirely configured from the command line
 $ init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf [-host pipeline_db_host] [-hc_capacity number_of_workers] [-hc_batch_size how_many_jobs_they_claim_at_a_time] [-allow_ambiguity_codes default_parameter_for_ambiguity_codes]
 $ seed_pipeline.pl -url ${EHIVE_URL} -logic_name pipeline_entry -input_id '{"db_conn" => "mysql://ensro\@compara1/mm14_protein_trees_77"}'
 $ beekeeper.pl -url ${EHIVE_URL} -loop
Note that allow_ambiguity_codes can be overriden in the input_id of the seeded job, and that multiple databases can be tested (one per seeded job)

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.0;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'host'                  => 'compara3',

        'hc_capacity'           =>  10,
        'hc_batch_size'         =>  20,

        'allow_ambiguity_codes' =>   0,

    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -hive_capacity      => $self->o('hc_capacity'),
            -batch_size         => $self->o('hc_batch_size'),
    );

    return [

        {   -logic_name => 'pipeline_entry',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT COUNT(*) AS species_count FROM genome_db',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                1 => [ 'all_trees_factory', 'hc_members_globally', 'hc_global_tree_set', 'default_trees_factory' ],
                2 => [ 'species_factory' ],
            },
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_globally',
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            %hc_analysis_params,
        },

        {   -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                2 => [ 'hc_members_per_genome', 'hc_pafs' ],
            },
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
                allow_ambiguity_codes   => $self->o('allow_ambiguity_codes'),
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_pafs',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'peptide_align_features',
            },
            %hc_analysis_params,
        },


        {   -logic_name => 'all_trees_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree"',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'hc_tree_structure', 'hc_tree_attributes' ],
            },
        },

        {   -logic_name         => 'hc_alignment',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_tree_structure',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_structure',
            },
            %hc_analysis_params,
        },

        {   -logic_name         => 'hc_tree_attributes',

            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_attributes',
            },
            %hc_analysis_params,
        },

        {   -logic_name => 'default_trees_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id = "default"',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'hc_alignment', 'hc_tree_homologies' ],
            },
        },

        {   -logic_name         => 'hc_tree_homologies',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_homologies',
            },
            %hc_analysis_params,
        },

    ];
}



1;

