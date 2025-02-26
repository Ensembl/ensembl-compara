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

Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf -host mysql-ens-compara-prod-X -port XXXX \
        -prev_tree_db <db_alias_or_url> -collection <collection> -member_type <protein|ncrna> \
        -division <division> -pipeline_name <pipeline_name>

=head1 DESCRIPTION

Pipeline to update the member_ids of a gene-tree database (in case the members
have been reloaded).
The pipeline also runs extensive healthchecks to make sure that the trees are
still valid.

=over

=item master_db

The location of the master database, from which the NCBI taxonomy, the GenomeDBs
and the MLSSs are copied over.

=item member_db

The location of the freshest load of members

=item prev_tree_db

The location of the gene-trees database. the pipeline will copy all the relevant
tables from there, and reindex the member_ids to make them match the new members.

=item member_type

Member type (protein or ncrna) used B<only> to name the pipeline database. The
pipeline will automatically discover the member type of the database being
reindexed.

=back

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_pipeline_name {
    my ($self) = @_;
    return join('_', $self->o('collection'), $self->o('member_type'), 'reindexed_trees');
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # Where to find the shared databases (use URLs or registry names)
        'master_db' => 'compara_master',
        'member_db' => 'compara_members',

        # Copy from master db
        'tables_from_master'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],

        # ambiguity codes
        'allow_ambiguity_codes'    => 0,

        # Analyses usually don't fail
        'hive_default_max_retry_count'  => 1,

        # Main capacity for the pipeline
        'copy_capacity'                 => 4,

        # Whole db DC parameters
        'datacheck_groups' => ['compara_gene_tree_pipelines'],
        'db_type'          => ['compara'],
        'work_dir'         => $self->o('pipeline_dir'),
        'output_dir_path'  => $self->o('work_dir') . '/datachecks/',
        'overwrite_files'  => 1,
        'failures_fatal'   => 1, # no DC failure tolerance
        'db_name'          => $self->o('dbowner') . '_' . $self->o('pipeline_name'),

        # Params for healthchecks;
        'hc_capacity'                     => 40,
        'hc_batch_size'                   => 10,

        # GenomeDB reindexing parameters
        'do_genome_reindexing'  => 0,
        'genome_reindexing_dir' => $self->o('work_dir') . '/' . 'genome_reindexing',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        $self->pipeline_create_commands_rm_mkdir(['genome_reindexing_dir', 'output_dir_path']),

        $self->db_cmd('CREATE TABLE datacheck_results (
                          submission_job_id INT,
                          dbname VARCHAR(255) NOT NULL,
                          passed INT,
                          failed INT,
                          skipped INT,
                          INDEX submission_job_id_idx (submission_job_id)
                     )'),

    ];
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'master_db'     => $self->o('master_db'),
        'member_db'     => $self->o('member_db'),
        'prev_tree_db'  => $self->o('prev_tree_db'),
        'collection'    => $self->o('collection'),
        'member_type'   => $self->o('member_type'),
        'ensembl_release' => $self->o('ensembl_release'),
        'output_dir_path' => $self->o('output_dir_path'),
        'db_name'         => $self->o('db_name'),

        # GenomeDB reindexing parameters
        'do_genome_reindexing'  => $self->o('do_genome_reindexing'),
        'genome_reindexing_dir' => $self->o('genome_reindexing_dir'),
    }
}


sub core_pipeline_analyses {
    my ($self) = @_;

    my $hc_analyses = Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf::pipeline_analyses($self);
    # Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf is meant
    # to run on db_conn, but species_factory only understands compara_db.
    # In this pipeline here, both default to the current db, so no need to
    # set the parameter
    delete $_->{'-parameters'}->{'compara_db'} for grep {$_->{'-logic_name'} eq 'species_factory'} @$hc_analyses;

    return [

# ------------------------------------------------------[copy tables from master]-----------------------------------------------------

        {   -logic_name => 'copy_tables_from_master_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name', 'method_link' ],
                'column_names' => [ 'table' ],
            },
            -input_ids  => [ {} ],
            -flow_into  => {
                '2->A' => 'copy_table_from_master',
                'A->1' => 'load_mlss_id',
            },
        },

        {   -logic_name => 'copy_table_from_master',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => '#master_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },

# -------------------------------------------[load GenomeDB entries and copy the other tables]------------------------------------------

        {   -logic_name => 'load_mlss_id',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -parameters => {
                'method_type'      => ($self->o('member_type') eq 'protein' ? 'PROTEIN_TREES' : 'NC_TREES'),
                'species_set_name' => $self->o('collection'),
                'release'          => '#ensembl_release#',
                'add_prev_mlss'    => 1,
            },
            -flow_into  => 'load_genomedb_factory',
        },

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'extra_parameters'  => [ 'locator' ],
            },
            -flow_into => {
                '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, }, # fan
                'A->1' => 'create_mlss_ss',
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -analysis_capacity => $self->o('copy_capacity'),
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'        => [ $self->o('member_type') eq "protein" ? 'PROTEIN_TREES' : 'NC_TREES' ],
                'singleton_method_links'    => [ 'ENSEMBL_PARALOGUES', 'ENSEMBL_HOMOEOLOGUES' ],
                'pairwise_method_links'     => [ 'ENSEMBL_ORTHOLOGUES' ],
            },
            -flow_into  => {
                1 => 'load_members_factory',
            },
        },

        {   -logic_name => 'load_members_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => { 'genome_member_copy' => INPUT_PLUS },
                'A->1' => 'fire_gene_tree_table_copy',
            },
        },

        {   -logic_name        => 'genome_member_copy',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters        => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => q{#expr(#member_type# eq "protein" ? 'biotype_group = "coding"' : 'biotype_group LIKE "%noncoding"')expr#},
            },
            -analysis_capacity => $self->o('copy_capacity'),
        },

        {   -logic_name    => 'fire_gene_tree_table_copy',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into     => WHEN(
                '#do_genome_reindexing#' => 'prep_genome_reindexing',
                ELSE 'assert_mlsses_match',
            ),
        },

        {   -logic_name => 'prep_genome_reindexing',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::PrepGenomedbReindexing',
            -rc_name    => '2Gb_job',
            -parameters => {
                'genome_dumps_dir' => $self->o('genome_dumps_dir'),
            },
            -flow_into  => 'gene_tree_tables_factory',
        },

        {   -logic_name    => 'assert_mlsses_match',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::AssertNumericParamsEqual',
            -parameters        => {
                'param_names' => ['mlss_id', 'prev_mlss_id'],
            },
            -flow_into     => 'gene_tree_tables_factory',
        },

        {   -logic_name => 'gene_tree_tables_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::TableFactory',
            -flow_into  => {
                '2->A' => 'copy_table_from_prev_db',
                'A->1' => 'map_members_factory',
            },
        },

        {   -logic_name    => 'copy_table_from_prev_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#prev_tree_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -analysis_capacity => $self->o('copy_capacity'),
            -flow_into  => WHEN(
                '#do_genome_reindexing# && #num_reindexed_genomes# > 0' => { 'reindex_genomes' => INPUT_PLUS() }
            ),
        },

        {   -logic_name    => 'reindex_genomes',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::ReindexGenomedbs',
            -hive_capacity => 1,  # Because of transactions, concurrent jobs will have deadlocks
        },

# ---------------------------------------------[Update the gene-tree tables]---------------------------------------------

        {   -logic_name => 'map_members_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => 'map_member_ids',
                'A->1' => 'reindex_member_ids',
            },
        },

        {   -logic_name        => 'map_member_ids',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::MapMemberIDs',
            -flow_into         => {
                2 => 'delete_old_member',
                3 => [
                    '?accu_name=seq_member_id_pairs&accu_address=[]&accu_input_variable=seq_member_ids',
                    '?accu_name=gene_member_id_pairs&accu_address=[]&accu_input_variable=gene_member_ids',
                ],
            },
        },

        {   -logic_name        => 'delete_old_member',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::DeleteOldMember',
            -hive_capacity     => 1,    # Because of transactions, concurrent jobs will have deadlocks
            -flow_into         => {
                2 => 'delete_tree',
            },
        },

        {   -logic_name        => 'delete_tree',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DeleteOneTree',
            -hive_capacity     => 1,    # Because of transactions, concurrent jobs will have deadlocks
        },

        {   -logic_name        => 'reindex_member_ids',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::ReindexMemberIDs',
            -flow_into         => {
                1 => 'reset_renamed_and_deleted_gene_members',
            },
        },

        # Will catch gene_member_hom_stats that could not be reset by
        # delete_tree because the gene_member_id is also renamed
        {   -logic_name        => 'reset_renamed_and_deleted_gene_members',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters        => {
                'sql'   => 'UPDATE gene_member_hom_stats JOIN gene_member USING (gene_member_id) LEFT JOIN gene_tree_node ON canonical_member_id = seq_member_id SET gene_trees = 0, orthologues = 0, paralogues = 0, homoeologues = 0 WHERE node_id IS NULL AND gene_trees > 0',
            },
            -flow_into         => {
                1 => 'fire_datachecks',
            },
        },

        {   -logic_name => 'delete_flat_trees_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) GROUP BY root_id HAVING COUNT(*) = COUNT(seq_member_id)+1 AND COUNT(seq_member_id) > 2',
            },
            -flow_into  => {
                '2->A' => 'delete_tree',
                'A->1' => 'cluster_factory',
            },
        },

        {   -logic_name    => 'fire_datachecks',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into     => {
                '1->A' => { 'delete_flat_trees_factory' => INPUT_PLUS },
                'A->1' => { 'datacheck_factory' => { 'datacheck_groups' => $self->o('datacheck_groups'), 'db_type' => $self->o('db_type'), 'compara_db' => $self->pipeline_url(), 'registry_file' => undef }},
            }
        },

        {   -logic_name     => 'cluster_factory',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters     => {
                'inputquery'    => 'SELECT root_id AS gene_tree_id FROM gene_tree_root WHERE tree_type = "tree" AND ref_root_id IS NULL',
            },
            -flow_into      => {
                '2->A' => 'exon_boundaries_prep',
                'A->1' => 'pipeline_entry',
                1      => 'hc_deletion',
            },
        },
        {   -logic_name     => 'hc_deletion',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::DeletionHealthcheck',
            -parameters     => {
                'diff_limit'    => -2.5,
            },
            -flow_into      => {
            },
        },

        {   -logic_name     => 'exon_boundaries_prep',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries',
            -flow_into      => {
                -1 => 'exon_boundaries_prep_himem',
            },
            -hive_capacity  => 100,
            -batch_size     => 20,
        },

        {   -logic_name     => 'exon_boundaries_prep_himem',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectStore::GeneTreeAlnExonBoundaries',
            -rc_name        => '2Gb_job',
            -hive_capacity  => 100,
            -batch_size     => 20,
        },

        @$hc_analyses,
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory::pipeline_analyses_datacheck_factory($self) },
    ];
}

sub tweak_analyses {
        my $self = shift;
        my $analyses_by_name = shift;
        # datacheck specific tweaks for pipelines
        $analyses_by_name->{'datacheck_factory'}->{'-parameters'} = {'dba' => '#compara_db#'};
        $analyses_by_name->{'store_results'}->{'-parameters'} = {'dbname' => '#db_name#'};
}

1;

