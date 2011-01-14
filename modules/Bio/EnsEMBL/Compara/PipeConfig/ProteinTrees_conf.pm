
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

=head1 DESCRIPTION  

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks (including blast reuse and finding out entry data for dNdS).

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

#       'mlss_id'           => 40069,   # it is very important to check that this value is current!

    # template parameters:
        'blast_options'             => '-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1',

    # clustering parameters:
        'outgroups'                 => [106],   # affects 'hcluster_prepare' and 'hcluster_run'
        'clustering_max_gene_count' => 1500,    # affects 'hcluster_run'

    # tree building parameters:
        'tree_max_gene_count'       => 400,     # affects 'njtree_phyml', 'ortho_tree' and 'quick_tree_break'
        'use_genomedb_id'           => 0,       # affects 'njtree_phyml' and 'ortho_tree'

    # homology_dnds parameters:
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/protein_trees.codeml.ctl.hash',      # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],


        'release'           => '61',
        'rel_suffix'        => 'e',    # an empty string by default, a letter otherwise
        'rel_with_suffix'   => $self->o('release').$self->o('rel_suffix'),

        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/work',     # some Compara developers might prefer $ENV{'HOME'}.'/ensembl_main'
        'work_dir'             => '/lustre/scratch101/ensembl/'.$ENV{'USER'}.'/protein_trees_'.$self->o('rel_with_suffix'),
        'fasta_dir'            => $self->o('work_dir') . '/bDB',
        'cluster_dir'          => $self->o('work_dir') . '/c',

        'email'             => $ENV{'USER'}.'@ebi.ac.uk',    # NB: your EBI address may differ from the Sanger one!

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                    
            -dbname => $ENV{'USER'}.'_compara_homology_'.$self->o('rel_with_suffix'),
        },

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'livemirror_loc' => {                     # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
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

        # # "production mode"
        # 'reuse_core_sources_locs'   => [ $self->o('livemirror_loc') ],
        # 'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
        # 'prev_release'              => 0,   # 0 is the default and it means "take current release number and subtract 1"
        #'reuse_db' => {   # usually previous release database on compara1
        #    -host   => 'compara1',
        #    -port   => 3306,
        #    -user   => 'ensro',
        #    -pass   => '',
        #    -dbname => 'kb3_ensembl_compara_60',
        #},

        # mode for testing the non-Blast part of the pipeline: reuse all Blasts
        'reuse_core_sources_locs' => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
        'curr_core_sources_locs'  => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
        'prev_release'            => $self->o('release'),
        'reuse_db' => {   # current release if we are testing after production
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_61',
        },

    };
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        'pipeline_name'     => 'PT_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
        'email'             => $self->o('email'),                   # for automatic notifications (may be unsupported by your Meadows)
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('fasta_dir'),
        'lfs setstripe '.$self->o('fasta_dir').' -c -1',    # stripe
        'mkdir -p '.$self->o('cluster_dir'),
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
         0 => { -desc => 'default',          'LSF' => '' },
         1 => { -desc => 'hcluster_run',     'LSF' => '-C0 -M25000000 -q hugemem -R"select[mycompara2<500 && mem>25000] rusage[mycompara2=10:duration=10:decay=1:mem=25000]"' },
         2 => { -desc => 'mcoffee_himem',    'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

# ---------------------------------------------[Blast template]--------------------------------------------------------------------------

        {   -logic_name         => 'blast_template',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -program            => 'wublastp',
            -program_version    => '1',
            -program_file       => 'wublastp',
            -parameters         => {
                'mlss_id'       => $self->o('mlss_id'),
                'reuse_db'      => $self->dbconn_2_url('reuse_db'),
                'blast_options' => $self->o('blast_options'),
            },
        },

# ---------------------------------------------[rename PAF tables]-----------------------------------------------------------------------

        {   -logic_name    => 'rename_paf_tables',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql' => [ 'RENAME TABLE peptide_align_feature TO peptide_align_feature_orig',
                           'RENAME TABLE peptide_align_feature_prod TO peptide_align_feature',
                ],
            },
            -input_ids  => [
                { },
            ],
            -flow_into => {
                1 => [ 'copy_table_factory' ],
            },
        },

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'   => $self->o('master_db'),
                'inputlist' => [ 'method_link', 'species_set', 'method_link_species_set', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                'input_id'  => { 'src_db_conn' => '#db_conn#', 'table' => '#_range_start#' },
                'fan_branch_code' => 2,
            },
            -wait_for  => [ 'rename_paf_tables' ],
            -flow_into => {
                2 => [ 'copy_table'  ],
                1 => [ 'innodbise_table_factory' ],     # backbone
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
            },
            -hive_capacity => 10,
        },

# ---------------------------------------------[turn all tables except 'genome_db' to InnoDB]---------------------------------------------

        {   -logic_name => 'innodbise_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='genome_db' AND engine='MyISAM' ",
                'input_id'        => { 'table_name' => '#_range_start#' },
                'fan_branch_code' => 2,
            },
            -wait_for  => [ 'copy_table' ],
            -flow_into => {
                2 => [ 'innodbise_table'  ],
                1 => [ 'generate_reuse_ss' ],           # backbone
            },
        },

        {   -logic_name    => 'innodbise_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
            },
            -hive_capacity => 10,
        },

# ---------------------------------------------[generate an empty species_set for reuse (to be filled in at a later stage) ]---------

        {   -logic_name => 'generate_reuse_ss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  "INSERT INTO species_set VALUES ()",   # inserts a dummy pair (auto_increment++, 0) into the table
                            "DELETE FROM species_set WHERE species_set_id=#_insert_id_0#", # will delete the row previously inserted, but keep the auto_increment
                ],
            },
            -wait_for  => [ 'innodbise_table' ],
            -flow_into => {
                2 => { 'mysql:////meta' => { 'meta_key' => 'reuse_ss_id', 'meta_value' => '#_insert_id_0#' } },     # dynamically record it as a pipeline-wide parameter
                1 => [ 'load_genomedb_factory' ],       # backbone
            },
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
                1 => { 'create_species_tree' => undef,
                       'accumulate_reuse_ss' => undef,  # backbone
                       'load_reuse_members' => { 'bypass_all' => 1 },   # fight the "empty analysis is always blocked" restriction (should be fixed on Hive level)
                       'load_fresh_members' => { 'bypass_all' => 1 },   # fight the "empty analysis is always blocked" restriction (should be fixed on Hive level)
                },
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
            },
            -hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
            -flow_into => {
                1 => [ 'check_reusability' ],   # each will flow into another one
            },
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------

        {   -logic_name    => 'create_species_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'db_url'   => $self->dbconn_2_url('pipeline_db'),
                'species_tree_file' => $self->o('work_dir').'/spec_tax.nh',
                'cmd'      => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/tree/testTaxonTree.pl -url #db_url# -create_species_tree -njtree_output_filename #species_tree_file# -no_other_files 2>/dev/null',
            },
            -wait_for => [ 'load_genomedb_factory', 'load_genomedb' ],  # have to wait for both to complete (so is a funnel)
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                1 => { 'store_species_tree' => { 'species_tree_file' => '#species_tree_file#' } },
            },
        },

        {   -logic_name    => 'store_species_tree',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',     # a non-standard use of JobFactory for iterative insertion
            -parameters => {
                'inputcmd'        => 'cat #species_tree_file#',
                'input_id'        => { 'node_id' => 1, 'tag' => 'species_tree_string', 'value' => '#_range_start#' },
                'fan_branch_code' => 3,
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                3 => [ 'mysql:////protein_tree_tag' ],
            },
        },

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
                'registry_dbs'  => $self->o('reuse_core_sources_locs'),
                'release'       => $self->o('release'),
                'prev_release'  => $self->o('prev_release'),
            },
            -hive_capacity => 10,    # allow for parallel execution
            -flow_into => {
                2 => { 'load_reuse_members'     => undef,
                       'paf_table_reuse'        => undef,
                       'mysql:////species_set'  => { 'genome_db_id' => '#genome_db_id#', 'species_set_id' => '#reuse_ss_id#' },
                },
                3 => [ 'load_fresh_members' ],
            },
        },

        {   -logic_name    => 'accumulate_reuse_ss',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',     # a non-standard use of JobFactory for iterative insertion
            -parameters => {
                'inputquery'      => 'SELECT GROUP_CONCAT(genome_db_id) FROM species_set WHERE species_set_id=#reuse_ss_id#',
                'input_id'        => { 'meta_key' => 'reuse_ss_csv', 'meta_value' => '#_range_start#' },
                'fan_branch_code' => 3,
            },
            -wait_for => [ 'load_genomedb', 'check_reusability' ],
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                3 => [ 'mysql:////meta' ],
            },
        },

# ---------------------------------------------[reuse members and pafs]--------------------------------------------------------------

        {   -logic_name => 'load_reuse_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ReuseOrLoadMembers',
            -parameters => {
                'reuse_db'      => $self->dbconn_2_url('reuse_db'),     # FIXME: remove the first-hash-to-url-then-hash-from-url code redundancy
            },
            -wait_for => [ 'accumulate_reuse_ss' ],   # fight the "empty analysis is always blocked" restriction (should be fixed on Hive level)
            -hive_capacity => -1,
            -flow_into => {
                1 => [ 'dump_fasta_create_blast_analyses', 'store_sequences_factory' ],
            },
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'peptide_align_feature_#name_and_id#',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
            },
            -wait_for   => [ 'accumulate_reuse_ss' ],     # have to wait until reuse_ss is fully populated
            -hive_capacity => 4,
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'load_fresh_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ReuseOrLoadMembers',
            -parameters => {
                'reuse_db'      => $self->dbconn_2_url('reuse_db'),     # FIXME: remove the first-hash-to-url-then-hash-from-url code redundancy
            },
            -wait_for => [ 'load_reuse_members' ],
            -hive_capacity => -1,
            -flow_into => {
                1 => [ 'dump_fasta_create_blast_analyses', 'store_sequences_factory' ],
            },
        },

# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'dump_fasta_create_blast_analyses',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta',
            -parameters => {
                'fasta_dir'                 => $self->o('fasta_dir'),
                'beforeblast_logic_name'    => 'load_fresh_members',
                'afterblast_logic_name'     => 'hcluster_prepare',
            },
            -wait_for => [ 'load_fresh_members', 'paf_table_reuse' ],   # actually it is Blast_* analyses that have to wait for 'paf_table_reuse', but it is tricky to achieve
            -hive_capacity => 1,
            -flow_into => {
                2 => [ 'populate_blast_analyses' ],
                1 => [ 'hcluster_prepare' ],
            },
        },

        {   -logic_name => 'populate_blast_analyses',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep',
            -parameters => {
                'new_format'    => 1,
            },
            -hive_capacity => 1,
        },

# ---------------------------------------------[sequence caching step]---------------------------------------------------------------

        {   -logic_name => 'store_sequences_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory',
            -parameters => { },
            -hive_capacity => -1,
            -flow_into => {
                2 => [ 'store_sequences' ],
            },
        },

        {   -logic_name => 'store_sequences',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FlowMemberSeq',
            -parameters => { },
            -hive_capacity => 200,
            -flow_into => {
                2 => [ 'mysql:////sequence_cds' ],
                3 => [ 'mysql:////sequence_exon_bounded' ],
            },
        },

# ---------------------------------------------[clustering step]---------------------------------------------------------------------

        {   -logic_name => 'hcluster_prepare',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare',
            -parameters => {
                'mlss_id'       => $self->o('mlss_id'),
                'outgroups'     => $self->o('outgroups'),
                'cluster_dir'   => $self->o('cluster_dir'),
            },
            -wait_for => [ 'dump_fasta_create_blast_analyses' ],    # more control rules are created by 'dump_fasta_create_blast_analyses'
            -hive_capacity => 4,
            -flow_into => {
                1 => [ 'clusterset_qc' ],
            },
        },

        {   -logic_name => 'hcluster_run',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterRun',
            -parameters => {
                'mlss_id'                   => $self->o('mlss_id'),
                'outgroups'                 => $self->o('outgroups'),
                'cluster_dir'               => $self->o('cluster_dir'),
                'max_gene_count'            => $self->o('clustering_max_gene_count'),
            },
            -wait_for => [ 'hcluster_prepare' ],
            -input_ids => [
                { },   # backbone
            ],
            -hive_capacity => -1,
            -flow_into => {
                1 => [ 'clusterset_qc', 'group_genomes_under_taxa' ],  # backbone 
                2 => [ 'mcoffee' ],
            },
            -rc_id => 1,
        },

# ---------------------------------------------[a QC step before main loop]----------------------------------------------------------

        {   -logic_name => 'clusterset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->dbconn_2_url('reuse_db'),     # FIXME: remove the first-hash-to-url-then-hash-from-url code redundancy
                'cluster_dir'               => $self->o('cluster_dir'),
                'groupset_tag'              => 'ClustersetQC',
            },
            -wait_for => [ 'hcluster_run' ],
            -hive_capacity => 3,
            -flow_into => {
                1 => [ 'gene_treeset_qc' ],
            },
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name => 'mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -program_file => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
            -parameters => {
                'method'                    => 'cmcoffee',      # presumably, at the moment it refers to the 'initial' method
                'use_exon_boundaries'       => 2,
            },
            -wait_for => [ 'store_sequences', 'clusterset_qc' ],
            -hive_capacity        => 600,
            -flow_into => {
                1 => [ 'njtree_phyml' ],
               -1 => [ 'mcoffee_himem' ],
            },
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -program_file => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
            -parameters => {
                'method'                    => 'cmcoffee',      # presumably, at the moment it refers to the 'initial' method
                'use_exon_boundaries'       => 2,
            },
            -hive_capacity        => 600,
            -flow_into => {
                1 => [ 'njtree_phyml' ],
            },
            -rc_id => 2,
        },

        {   -logic_name => 'njtree_phyml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -program_file => '/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest/treebest',
            -parameters => {
                'cdna'                      => 1,
                'bootstrap'                 => 1,
                'max_gene_count'            => $self->o('tree_max_gene_count'),
#                'species_tree_file'         => $self->o('work_dir').'/spec_tax.nh', # FIXME: theoretically, the module is capable of getting the tree from protein_tree_tag table
                'use_genomedb_id'           => $self->o('use_genomedb_id'),
            },
            -hive_capacity        => 400,
            -failed_job_tolerance => 5,
            -flow_into => {
                1 => [ 'ortho_tree' ],
                2 => [ 'njtree_phyml' ],
                3 => [ 'quick_tree_break' ],
            },
        },

        {   -logic_name => 'ortho_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthoTree',
            -parameters => {
                'max_gene_count'            => $self->o('tree_max_gene_count'),
#                'species_tree_file'         => $self->o('work_dir').'/spec_tax.nh', # FIXME: theoretically, the module is capable of getting the tree from protein_tree_tag table
                'use_genomedb_id'           => $self->o('use_genomedb_id'),
            },
            -hive_capacity        => 200,
            -failed_job_tolerance => 5,
            -flow_into => {
                1 => [ 'build_HMM_aa', 'build_HMM_cds' ],
                2 => [ 'quick_tree_break' ],
            },
        },

        {   -logic_name => 'build_HMM_aa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -program_file => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
            -parameters => {
                'sreformat'                 => '/usr/local/ensembl/bin/sreformat',
            },
            -hive_capacity        => 200,
            -failed_job_tolerance => 5,
        },

        {   -logic_name => 'build_HMM_cds',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -program_file => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
            -parameters => {
                'cdna'                      => 1,
                'sreformat'                 => '/usr/local/ensembl/bin/sreformat',
            },
            -hive_capacity        => 200,
            -failed_job_tolerance => 5,
        },

        {   -logic_name => 'quick_tree_break',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak',
            -parameters => {
                'max_gene_count'            => $self->o('tree_max_gene_count'),
            },
            -hive_capacity        => 1, # this one seems to slow the whole loop down; why can't we have any more of these?
            -failed_job_tolerance => 5,
            -flow_into => {
                1 => [ 'other_paralogs' ],
                2 => [ 'mcoffee' ],
            },
        },

        {   -logic_name => 'other_paralogs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OtherParalogs',
            -parameters => { },
            -wait_for => [ 'mcoffee', 'mcoffee_himem', 'njtree_phyml', 'ortho_tree', 'build_HMM_aa', 'build_HMM_cds', 'quick_tree_break' ],
            -hive_capacity        => 50,
            -failed_job_tolerance => 5,
        },

# ---------------------------------------------[a QC step after main loop]----------------------------------------------------------

        {   -logic_name => 'gene_treeset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->dbconn_2_url('reuse_db'),     # FIXME: remove the first-hash-to-url-then-hash-from-url code redundancy
                'cluster_dir'               => $self->o('cluster_dir'),
                'groupset_tag'              => 'GeneTreesetQC',
            },
            -wait_for => [ 'mcoffee', 'mcoffee_himem', 'njtree_phyml', 'ortho_tree', 'quick_tree_break' ],
            -hive_capacity => 3,
        },

# ---------------------------------------------[homology step]-----------------------------------------------------------------------

        {   -logic_name => 'group_genomes_under_taxa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupHighCoverageGenomesUnderTaxa',
            -parameters => {
                'mlss_id'   => $self->o('mlss_id'),
                'taxlevels' => $self->o('taxlevels'),
            },
            -wait_for => [ 'gene_treeset_qc' ],
            -hive_capacity => -1,
            -flow_into => {
                2 => [ 'homology_dNdS_factory' ],
            },
        },

        {   -logic_name => 'homology_dNdS_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyGroupingFactory',
            -parameters => { },
            -hive_capacity => -1,
            -flow_into => {
                1 => [ 'threshold_on_dS' ],
                2 => [ 'homology_dNdS' ],
            },
        },

        {   -logic_name => 'homology_dNdS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Homology_dNdS',
            -parameters => {
                'codeml_parameters_file'    => $self->o('codeml_parameters_file'),
            },
            -hive_capacity        => 200,
            -failed_job_tolerance => 2,
        },

        {   -logic_name => 'threshold_on_dS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS',
            -parameters => { },
            -wait_for => [ 'homology_dNdS' ],
            -hive_capacity => -1,
        },

# ---------------------------------------------[homology duplications QC step]-------------------------------------------------------

        {   -logic_name => 'homology_duplications_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MLSSfactory',
            -parameters => {
                'input_id' => { 'type' => '#short_type#', 'mlss_id' => '#_range_start#' },
                'fan_branch_code' => 2,
            },
            -wait_for => [ 'threshold_on_dS' ],
            -input_ids => [
                { 'method_link_type' => 'ENSEMBL_ORTHOLOGUES', 'short_type' => 'orthologues' },
                { 'method_link_type' => 'ENSEMBL_PARALOGUES',  'short_type' => 'paralogues'  },
            ],
            -hive_capacity => -1,
            -flow_into => {
                2 => [ 'homology_duplications' ],
            },
        },

        {   -logic_name => 'homology_duplications',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HDupsQC',
            -parameters => { },
            -hive_capacity => 10,
        },

    ];
}

1;

