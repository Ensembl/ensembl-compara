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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf

=head1 DESCRIPTION

Pipeline to update the member_ids of a gene-tree database (in case the members
have been reloaded).
The pipeline also runs extensive healthchecks to make sure that the trees are
still valid.

=over

=item mlss_id

The mlss_id of the gene-tree pipelines. Used to load the GenomeDBs and the MLSSs

=item master_db

The location of the master database, from which the NCBI taxonomy, the GenomeDBs
and the MLSSs are copied over.

=item curr_core_sources_locs

Where to find the core databases. Although the pipeline doesn't need anything from
them, the Runnable that loads the GenomeDBs needs them to check that the attributes
of the GenomeDBs are all in sync.

=item member_db

The location of the freshest load of members

=item member_type

Either "protein" or "ncrna". The type of members to pull from the memebr database

=item prev_rel_db

The location of the gene-trees database. the pipeline will copy all the relevant
tables from there, and reindex the member_ids to make them match the new members.

=back

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # Must be "protein" or "ncrna"
        #'member_type'   => undef,

        # Copy from master db
        'tables_from_master'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name' ],

        # ambiguity codes
        'allow_ambiguity_codes'    => 0,

        # Analyses usually don't fail
        'hive_default_max_retry_count'  => 1,

        # Main capacity for the pipeline
        'copy_capacity'                 => 4,

        # Params for healthchecks;
        'hc_capacity'                     => 40,
        'hc_batch_size'                   => 10,
    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'mlss_id'       => $self->o('mlss_id'),
        'master_db'     => $self->o('master_db'),
        'member_db'     => $self->o('member_db'),
        'prev_rel_db'   => $self->o('prev_rel_db'),
        'member_type'   => $self->o('member_type'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    my $hc_analyses = Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf::pipeline_analyses($self);
    # Bio::EnsEMBL::Compara::PipeConfig::GeneTreeHealthChecks_conf is meant
    # to run on db_conn, but species_factory only understands compara_db.
    # In this pipeline here, both default to the current db, so no need to
    # set the parameter
    delete $_->{'-parameters'}->{'compara_db'} for grep {$_->{'-logic_name'} eq 'species_factory'} @$hc_analyses;
    # Give more memory to these guys
    $_->{'-rc_name'} = '250Mb_job' for grep {$_->{'-logic_name'} =~ /trees_factory$/} @$hc_analyses;

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
                'A->1' => 'load_genomedb_factory',
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

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'        => '#master_db#',   # that's where genome_db_ids come from
                'mlss_id'           => $self->o('mlss_id'),
                'extra_parameters'  => [ 'locator' ],
            },
            -flow_into => {
                '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, }, # fan
                'A->1' => 'create_mlss_ss',
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'   => $self->o('curr_core_sources_locs'),
            },
            -analysis_capacity => $self->o('copy_capacity'),
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'whole_method_links'        => [ 'NC_TREES' ],
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
                '2->A' => 'genome_member_copy',
                'A->1' => 'gene_tree_tables_factory',
            },
        },

        {   -logic_name        => 'genome_member_copy',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB',
            -parameters        => {
                'reuse_db'              => '#member_db#',
                'biotype_filter'        => q{#expr(#member_type# eq "protein" ? 'biotype_group = "coding"' : 'biotype_group LIKE "%noncoding"')expr#},
            },
            -analysis_capacity => $self->o('copy_capacity'),
            -rc_name           => '250Mb_job',
        },

        {   -logic_name => 'gene_tree_tables_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::TableFactory',
            -flow_into  => {
                '2->A' => 'copy_table_from_prev_rel_db',
                'A->1' => 'map_members_factory',
            },
        },

        {   -logic_name    => 'copy_table_from_prev_rel_db',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'src_db_conn'   => '#prev_rel_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -analysis_capacity => $self->o('copy_capacity'),
        },

# ---------------------------------------------[Update the gene-tree tables]---------------------------------------------

        {   -logic_name => 'map_members_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A' => 'map_member_ids',
                'A->1' => 'delete_flat_trees_factory',
            },
        },

        {   -logic_name        => 'map_member_ids',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::MapMemberIDs',
            -hive_capacity     => 1,    # Because of transactions, concurrent jobs will have deadlocks
            -rc_name           => '250Mb_job',
            -flow_into         => {
                2 => 'delete_tree',
            }
        },

        {   -logic_name        => 'delete_tree',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DeleteOneTree',
            -hive_capacity     => 1,    # Because of transactions, concurrent jobs will have deadlocks
        },

        {   -logic_name => 'delete_flat_trees_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT root_id AS gene_tree_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) GROUP BY root_id HAVING COUNT(*) = COUNT(seq_member_id)+1 AND COUNT(seq_member_id) > 2',
            },
            -flow_into  => {
                '2->A' => 'delete_tree',
                'A->1' => 'pipeline_entry',
            },
        },

        @$hc_analyses,
    ];
}

1;

