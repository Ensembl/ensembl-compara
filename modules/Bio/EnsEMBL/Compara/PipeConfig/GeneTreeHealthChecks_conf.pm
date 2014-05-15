=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name'         => 'HC',   # name the pipeline to differentiate the submitted processes

        'hc_capacity'           =>   4,

        # connection parameters to various databases:

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_tree_hc',
        },

        # The database that needs to be checked
        'db_conn' => {
           -host   => 'compara1',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'mm14_compara_homology_70c',
        },

    };
}

sub pipeline_wide_parameters {
    my $self = shift @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'db_conn'   => $self->o('db_conn'),
    }
}



sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'count_number_species',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT "species_count" AS meta_key, COUNT(*) AS meta_value FROM genome_db',
                'fan_branch_code'   => 2,
            },
            -input_ids  => [ {} ],
            -flow_into => {
                1 => [ 'species_factory', 'tree_factory', 'hc_members_globally', 'hc_global_tree_set' ],
                2 => [ 'mysql:////meta' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name         => 'hc_members_globally',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name         => 'hc_global_tree_set',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'global_tree_set',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name => 'species_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM genome_db',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'hc_members_per_genome', 'hc_pafs' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name         => 'hc_members_per_genome',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'members_per_genome',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name         => 'hc_pafs',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'peptide_align_features',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },


        {   -logic_name => 'tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree"',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                1 => [ 'homology_tree_factory' ],
                2 => [ 'hc_alignment', 'hc_tree_structure', 'hc_tree_attributes' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name         => 'hc_alignment',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'alignment',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name         => 'hc_tree_structure',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_structure',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name         => 'hc_tree_attributes',

            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_attributes',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

        {   -logic_name => 'homology_tree_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND clusterset_id = "default"',
                'fan_branch_code'   => 2,
            },
            -flow_into  => {
                2 => [ 'hc_tree_homologies' ],
            },
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name         => 'hc_tree_homologies',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters         => {
                mode            => 'tree_homologies',
            },
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
        },

    ];
}



1;

