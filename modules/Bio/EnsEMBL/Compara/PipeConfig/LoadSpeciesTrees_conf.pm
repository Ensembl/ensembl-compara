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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -compara_alias_name <db_alias_or_url>

=head1 DESCRIPTION

A pipeline to load the Compara species-trees into a database.
Currently, this includes:
 - The tree made automatically from the NCBI taxonomy
 - The binary tree that the Compara team maintains

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.3;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'species_tree_method_link' => 'SPECIES_TREE',

        'species_tree'             => $self->o('binary_species_tree'),

        'taxon_filters' => [
            # Filters with the default behaviour (strains hidden)
            # [ 'Amniota', 'Amniotes' ],
            # [ 'Mammalia', 'Mammals' ],
            # Filters with the strains shown, prefix with "str:"
            # [ 'str:Murinae', 'Rat and all mice (incl. strains)' ],
        ],
        'reference_genomes' => [
            # Which genome_dbs are used references for which clades
            # [ '10090', 'mus_musculus' ],
        ],

        'binary'    => 1,
        'n_missing_species_in_tree' => 0,
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack'  => 1,
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'compara_db'    => $self->o('compara_alias_name'),
        'db_conn'       => $self->o('compara_alias_name'),
    };
}



sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'find_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'species_tree_method_link'  => $self->o('species_tree_method_link'),
                'inputquery'    => 'SELECT method_link_species_set_id FROM method_link_species_set JOIN method_link USING (method_link_id) WHERE method_link.type = "#species_tree_method_link#" AND first_release IS NOT NULL AND last_release IS NULL',
            },
            -input_ids  => [ {} ],
            -flow_into  => {
                2 => [ 'load_ensembl_tree' ],
            },
        },

        {   -logic_name => 'load_ensembl_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters => {
                # Gets #compara_db# from pipeline_wide_parameters
                'label'     => 'Ensembl',
                'mlss_id'   => '#method_link_species_set_id#',
                'species_tree_input_file'   => $self->o('species_tree'),
            },
            -flow_into  => {
                2 => [ 'hc_ensembl_species_tree' ],
            }
        },

        {   -logic_name => 'hc_ensembl_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters => {
                # Gets #compara_db# from pipeline_wide_parameters
                mode            => 'species_tree',
                binary          => $self->o('binary'),
                n_missing_species_in_tree   => $self->o('n_missing_species_in_tree'),
            },
            -flow_into  => [ 'load_ncbi_tree' ],
        },

        {   -logic_name => 'load_ncbi_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters => {
                # Gets #compara_db# from pipeline_wide_parameters
                'label'     => 'NCBI Taxonomy',
                'mlss_id'   => '#method_link_species_set_id#',
                'allow_subtaxa' => 1,
            },
            -flow_into  => {
                2 => [ 'hc_species_tree' ],
            }
        },

        {   -logic_name => 'hc_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters => {
                # Gets #compara_db# from pipeline_wide_parameters
                mode            => 'species_tree',
                binary          => 0,
                n_missing_species_in_tree   => 0,
            },
            -flow_into  => [ 'insert_taxon_filters_factory', 'insert_reference_genomes_factory' ],
        },


        {   -logic_name => 'insert_taxon_filters_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => $self->o('taxon_filters'),
                'column_names' => [ 'scientific_name', 'common_name', 'prefix' ],
            },
            -flow_into => {
                2 => [ 'check_taxon_filters' ],
            },
        },

        {   -logic_name => 'check_taxon_filters',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'query'         => 'SELECT DISTINCT root_id FROM species_tree_root JOIN species_tree_node USING (root_id) WHERE method_link_species_set_id = #method_link_species_set_id# AND node_name = "#scientific_name#"',
                'expected_size' => '= 2',
            },
            -flow_into  => [ 'insert_taxon_filters' ],
        },

        {   -logic_name => 'insert_taxon_filters',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                # Cannot flow directly into the table because table-dataflows can only reach the eHive database, not #db_conn#
                # Gets #db_conn# from pipeline_wide_parameters
                'sql'       => 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#method_link_species_set_id#, "filter:#prefix##scientific_name#", "#common_name#")',
            },
        },


        {   -logic_name => 'insert_reference_genomes_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => $self->o('reference_genomes'),
                'column_names' => [ 'taxon_id', 'genome_db_name' ],
            },
            -flow_into => {
                2 => [ 'check_reference_genome' ],
            },
        },

        {   -logic_name => 'check_reference_genome',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'query'         => 'SELECT genome_db_id FROM genome_db WHERE name = "#genome_db_name#"',
                'expected_size' => '= 1',
            },
            -flow_into  => [ 'check_taxon_id' ],
        },

        {   -logic_name => 'check_taxon_id',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'query'         => 'SELECT DISTINCT root_id FROM species_tree_root JOIN species_tree_node USING (root_id) WHERE method_link_species_set_id = #method_link_species_set_id# AND taxon_id = #taxon_id#',
                'expected_size' => '= 2',
            },
            -flow_into  => [ 'insert_reference_genomes' ],
        },

        {   -logic_name => 'insert_reference_genomes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                # Cannot flow directly into the table because table-dataflows can only reach the eHive database, not #db_conn#
                # Gets #db_conn# from pipeline_wide_parameters
                'sql'       => 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#method_link_species_set_id#, "ref_genome:#taxon_id#", "#genome_db_name#")',
            },
        },

    ];
}

1;

