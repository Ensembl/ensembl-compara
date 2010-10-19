
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf -password <your_password>

=head1 DESCRIPTION  

    Load GenomeDB entries, subsets and ncRNA members starting from a mlss_id or species_set_id (work in progress)

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'mlss_id'           => 40066,

        'release'           => '60',
        'rel_suffix'        => 'b',    # an empty string by default, a letter otherwise
        'rel_with_suffix'   => $self->o('release').$self->o('rel_suffix'),

        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/work',     # some Compara developers might prefer $ENV{'HOME'}.'/ensembl_main'
        'work_dir'             => $ENV{'HOME'}.'/ncrna_trees_'.$self->o('rel_with_suffix'),

        'email'             => $ENV{'USER'}.'@ebi.ac.uk',    # NB: your EBI address may differ from the Sanger one!

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                    
            -dbname => $ENV{'USER'}.'_compara_nctrees_'.$self->o('rel_with_suffix'),
        },

        'reg1' => {
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'reg2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'master_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        },

        'rel_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'kb3_ensembl_compara_60',
        },
    };
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        'pipeline_name'     => 'NCT_'.$self->o('rel_with_suffix'),  # name the pipeline to differentiate the submitted processes
        'email'             => $self->o('email'),                   # for automatic notifications (may be unsupported by your Meadows)
        'work_dir'          => $self->o('work_dir'),                # data directories and filenames
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('work_dir'),
    ];
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'   => $self->o('master_db'),
                'inputlist' => [ 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                'input_id'  => { 'src_db_conn' => '#db_conn#', 'table' => '#_range_start#' },
                'fan_branch_code' => 2,
            },
            -input_ids => [
                {},
            ],
            -flow_into => {
                2 => [ 'copy_table'  ],
                1 => [ 'offset_tables' ],  # backbone
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
            },
            -hive_capacity => 10,
        },

        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE member   AUTO_INCREMENT=200000001',
                    'ALTER TABLE sequence AUTO_INCREMENT=200000001',
                    'ALTER TABLE homology AUTO_INCREMENT=100000001',
                ],
            },
            -wait_for => [ 'copy_table_factory', 'copy_table' ],    # have to wait until the tables have been copied
            -flow_into => {
                1 => [ 'innodbise_table_factory' ],
            },
        },

# ---------------------------------------------[turn all tables except 'genome_db' to InnoDB]---------------------------------------------

        {   -logic_name => 'innodbise_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='genome_db' AND engine='MyISAM' ",
                'input_id'        => { 'table_name' => '#_range_start#' },
                'fan_branch_code' => 2,
            },
            -flow_into => {
                2 => [ 'innodbise_table'  ],
                1 => [ 'load_genomedb_factory' ],
            },
        },

        {   -logic_name    => 'innodbise_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
            },
            -hive_capacity => 10,
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadGenomedbFactory',
            -parameters => {
                'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
                'mlss_id'       => $self->o('mlss_id'),
            },
            -wait_for  => [ 'innodbise_table_factory', 'innodbise_table' ],
            -flow_into => {
                2 => [ 'load_genomedb' ],
                1 => [ 'create_species_tree' ],
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => [ $self->o('reg1'), $self->o('reg2'), ],
            },
            -flow_into => {
                1 => [ 'load_members_factory' ],   # each will flow into another one
            },
        },

# ---------------------------------------------[load ncRNA and gene members and subsets]---------------------------------------------

        {   -logic_name    => 'load_members_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GenomePrepareNCMembers',
            -hive_capacity => 10,
#temporary:
-wait_for => [ 'create_species_tree', 'store_species_tree' ],
            -flow_into => {
                2 => [ 'load_members' ],   # per-genome fan
            },
        },

        {   -logic_name    => 'load_members',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GeneStoreNCMembers',
            -hive_capacity => 20,
#temporary:
-wait_for => [ 'create_species_tree', 'store_species_tree' ],
            -flow_into => {
                3 => [ 'mysql:////subset_member' ],   # every ncrna member is added to the corresponding subset
                4 => [ 'mysql:////subset_member' ],   # every gene  member is added to the corresponding subset
            },
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------

        {   -logic_name    => 'create_species_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'db_url'   => $self->dbconn_2_url('pipeline_db'),
                'species_tree_file' => $self->o('work_dir').'/nctree_spec_tax.nh',
                'cmd'      => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/tree/testTaxonTree.pl -url #db_url# -create_species_tree -multifurcation_deletes_node 33316_129949_314146 -multifurcation_deletes_all_subnodes 9347_186625_32561 -njtree_output_filename #species_tree_file# -no_other_files 2>/dev/null',
            },
            -wait_for => [ 'load_genomedb_factory', 'load_genomedb' ],  # have to wait for both to complete (so is a funnel)
            -flow_into => {
                1 => { 'store_species_tree' => { 'species_tree_file' => '#species_tree_file#' } },
            },
        },

        {   -logic_name    => 'store_species_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputcmd'        => 'cat #species_tree_file#',
                'input_id'        => { 'node_id' => 1, 'tag' => 'species_tree_string', 'value' => '#_range_start#' },
                'fan_branch_code' => 3,
            },
            -flow_into => {
                3 => [ 'mysql:////nc_tree_tag' ],

                # can continue the backbone from here (but make sure to sync with the double fan!)
            },
        },

    ];
}

1;

