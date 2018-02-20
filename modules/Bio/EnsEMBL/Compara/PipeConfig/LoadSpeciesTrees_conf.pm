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

Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf -compara_alias_name compara_curr

=head1 DESCRIPTION

A pipeline to load the Compara species-trees into a database.
Currently, this includes:
 - The tree made automatically from the NCBI taxonomy
 - The binary tree that the Compara team maintains

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');      # we want to treat it as a 'pure' Hive pipeline



sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'species_tree_method_link' => 'SPECIES_TREE',

        'taxon_filters' => [
            # Filters with the default behaviour (strains hidden)
            [ 'Amniota', 'Amniotes' ],
            [ 'Mammalia', 'Mammals' ],
            [ 'Neopterygii', 'Fish' ],
            [ 'Sauria', 'Sauropsids' ],
            # Filters with the strains shown, prefix with "str:"
            [ 'str:Murinae', 'Rat and all mice (incl. strains)' ],
        ],
        'reference_genomes' => [
            # Which genome_dbs are used references for which clades
            [ 'ref_genome:10090', 'mus_musculus' ],
        ],

        'ensembl_species_tree' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.ensembl.branch_len.nw',

        'reg_conf'  => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl",

    };
}


# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack'  => 1,
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        'default' => { 'LSF' => ['', '--reg_conf '.$self->o('reg_conf')], 'LOCAL' => ['', '--reg_conf '.$self->o('reg_conf')] },
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
                'species_tree_input_file'   => $self->o('ensembl_species_tree'),
            },
            -flow_into  => {
                2 => [ 'hc_binary_species_tree' ],
            }
        },

        {   -logic_name => 'hc_binary_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks',
            -parameters => {
                # Gets #compara_db# from pipeline_wide_parameters
                mode            => 'species_tree',
                binary          => 1,
                n_missing_species_in_tree   => 0,
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
                'column_names' => [ 'scientific_name', 'common_name' ],
            },
            -flow_into => {
                2 => [ 'insert_taxon_filters' ],    # Cannot flow directly into the table because table-dataflows can only reach the eHive database, not #db_conn#
            },
        },

        {   -logic_name => 'insert_taxon_filters',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                # Gets #db_conn# from pipeline_wide_parameters
                'sql'       => 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#method_link_species_set_id#, "filter:#scientific_name#", "#common_name#")',
            },
        },


        {   -logic_name => 'insert_reference_genomes_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => $self->o('reference_genomes'),
                'column_names' => [ 'taxon_id', 'genome_db_name' ],
            },
            -flow_into => {
                2 => [ 'insert_reference_genomes' ],    # Cannot flow directly into the table because table-dataflows can only reach the eHive database, not #db_conn#
            },
        },

        {   -logic_name => 'insert_reference_genomes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                # Gets #db_conn# from pipeline_wide_parameters
                'sql'       => 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#method_link_species_set_id#, "ref_genome:#taxon_id#", "#genome_db_name#")',
            },
        },

    ];
}

1;

