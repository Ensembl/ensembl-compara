
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

    The PipeConfig file for ProteinTrees pipeline when the user input is a list of FASTA files

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ProteinTreesFromFASTA_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
	  'mlss_id'           => 100,
        'release'               => '2011_04',
        'rel_suffix'            => 'b',    # an empty string by default, a letter otherwise
        'work_dir'              => '/lustre/scratch101/ensembl/'.$ENV{'USER'}.'/quest_for_orthologs_'.$self->o('rel_with_suffix'),
        'data_dir'              => $self->o('work_dir').'/fasta',
	  'qfo_method_link_id'    => 401,
	  'qfo_species_set_id'    => 1,
	  'reuse_species_set_id'  => 2,

    # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
        'pipeline_name'         => 'QFO_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp_with_reuse'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',


    # blast parameters:
        'blast_options'             => '-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1',
        'blast_tmp_dir'             => '',  # if empty, will use Blast Analysis' default

    # clustering parameters:
        'outgroups'                     => [315277],   # affects 'hcluster_dump_input_per_genome'
        'clustering_max_gene_halfcount' => 750,     # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'

    # tree building parameters:
        'tree_max_gene_count'       => 400,     # affects 'mcoffee' and 'mcoffee_himem'
        'use_exon_boundaries'       => 0,       # affects 'mcoffee' and 'mcoffee_himem'
        'use_genomedb_id'           => 0,       # affects 'njtree_phyml' and 'ortho_tree'
        'species_tree_input_file'   => '',      # you can define your own species_tree for 'njtree_phyml' and 'ortho_tree'


    # executable locations:
        'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_exe'               => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
        'mafft_exe'                 => '/software/ensembl/compara/mafft-6.707/bin/mafft',
        'mafft_binaries'            => '/software/ensembl/compara/mafft-6.707/binaries',
        'sreformat_exe'             => '/usr/local/ensembl/bin/sreformat',
        'treebest_exe'              => '/nfs/users/nfs_m/mm14/workspace/treebest.qfo/treebest',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',

    # hive_capacity values for some analyses:
        'store_sequences_capacity'  => 200,
        'blastp_capacity'           => 450,
        'mcoffee_capacity'          => 600,
        'njtree_phyml_capacity'     => 400,
        'ortho_tree_capacity'       => 200,
        'build_hmm_capacity'        => 200,
        'other_paralogs_capacity'   =>  50,
        'homology_dNdS_capacity'    => 200,

    # connection parameters to various databases:

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                    
            -dbname => $ENV{'USER'}.'_quest_for_orthologs_'.$self->o('rel_with_suffix'),
        },

        'master_db' => {                        # the master database for copy of ncbi taxa
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'mm14_compara_homology_63',
        },

        'reuse_db' => {   # usually previous release database on compara1
           -host   => 'compara4',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'mm14_quest_for_orthologs_2011_04',
        },

    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('fasta_dir'),

            # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('fasta_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('fasta_dir').' -c -1 || echo "Striping is not available on this system" ',

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

# ---------------------------------------------[turn all tables except 'genome_db' to InnoDB]---------------------------------------------

        {   -logic_name => 'innodbise_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='genome_db' AND engine='MyISAM_FIXME' ",
                'fan_branch_code' => 2,
            },
		-input_ids  => [ { } ],
            -flow_into  => {
                2 => [ 'innodbise_table'  ],
            },
        },

        {   -logic_name    => 'innodbise_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
            },
            -hive_capacity => 10,
            -can_be_empty  => 1,
        },

# ---------------------------------------------[load species list from files]---------------------------------------------------

        {   -logic_name => 'load_species_list',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputcmd'      => '/bin/ls '.$self->o('data_dir').' | sed \'s/\([0-9]*\)_\(.*\).fasta/\1_\2.fasta \1 \2/\'' ,
                'delimiter'     => ' ',
                'column_names'  => [ 'filename', 'ncbi_taxon_id', 'species_name' ],
                'fan_branch_code' => 2,
            },
		-input_ids  => [ { } ],
            -flow_into => {
                1 => [ 'accumulate_reuse_ss' ],  # backbone
                2 => [ 'check_genome_reuse' ],   # fan n_species
            },
        },

        {   -logic_name    => 'accumulate_reuse_ss',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
		    'sql'           => [
		    		'INSERT INTO meta (meta_key, meta_value) SELECT "reuse_ss_csv", GROUP_CONCAT(genome_db_id) FROM species_set WHERE species_set_id='.$self->o('reuse_species_set_id'),
		    		'INSERT INTO meta (meta_key, meta_value) VALUES ("reuse_ss_id", '.$self->o('reuse_species_set_id').')',
		    ],
            },
		-wait_for => [ 'check_genome_reuse', 'store_genomedb', 'copy_genomedb' ],
            -flow_into => [ 'store_mlss' ],  # backbone
        },


        {   -logic_name => 'check_genome_reuse',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FromScratch::CheckGenomeReuse',
            -hive_capacity => 10,    # allow for parallel execution
            -parameters => {
                'reuse_db'      => $self->o('reuse_db'),
            },
		-flow_into => {
                2 => [ 'store_genomedb' ],  # n_new_species
                3 => [ 'copy_genomedb' ],   # n_reused_species
            },
        },

# ---------------------------------------------[reuse members and pafs]--------------------------------------------------------------

        {   -logic_name => 'copy_genomedb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
		    'sql'           => [
		    		'INSERT INTO genome_db (genome_db_id, taxon_id, name) VALUES (#genome_db_id#, #ncbi_taxon_id#, "#species_name#")',
		    		'INSERT INTO species_set (species_set_id, genome_db_id) VALUES ('.$self->o('qfo_species_set_id').',#genome_db_id#)',
		    		'INSERT INTO species_set (species_set_id, genome_db_id) VALUES ('.$self->o('reuse_species_set_id').',#genome_db_id#)',
		    ],
            },
            -can_be_empty  => 1,
            -hive_capacity => 4,
		-flow_into => [ 'subset_table_reuse' ],  # n_reused_species
        },

        {   -logic_name => 'subset_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'subset',
                'mode'          => 'insertignore',
                'where'         => 'description LIKE "gdb:#genome_db_id# %"',
            },
            -can_be_empty  => 1,
            -hive_capacity => 4,
            -flow_into => [ 'subset_member_table_reuse' ],    # n_reused_species
        },

        {   -logic_name => 'subset_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('reuse_db'),
                            'inputquery' => "SELECT sm.* FROM subset_member sm JOIN subset USING (subset_id) WHERE description LIKE 'gdb:#genome_db_id# %'",
                            'fan_branch_code' => 2,
            },
            -can_be_empty  => 1,
            -hive_capacity => 4,
            -flow_into => {
                1 => [ 'member_table_reuse' ],    # n_reused_species
                2 => [ 'mysql:////subset_member' ],
            },
        },

        {   -logic_name => 'member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'member',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
		 },
            -can_be_empty  => 1,
            -hive_capacity => 4,
            -flow_into => [ 'sequence_table_reuse' ],   # n_reused_species
        },

        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('reuse_db'),
                            'inputquery' => 'SELECT s.* FROM sequence s JOIN member USING (sequence_id) WHERE genome_db_id = #genome_db_id#',
                            'fan_branch_code' => 2,
            },
            -can_be_empty  => 1,
            -hive_capacity => 4,
            -flow_into => {
                1 => [ 'paf_table_reuse' ],     # n_reused_species
                2 => [ 'mysql:////sequence' ],
            },
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'peptide_align_feature_#species_name#_#genome_db_id#',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
                'mode'          => 'overwrite',
            },
            -can_be_empty  => 1,
            -hive_capacity => 4,
		-wait_for => [ 'accumulate_reuse_ss' ],
            -flow_into => [ 'dump_subset_create_blastdb' ],   # n_reused_species
        },


# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'store_genomedb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
		    'sql'           => [
		    		'INSERT INTO genome_db (taxon_id, name) VALUES (#ncbi_taxon_id#, "#species_name#")',
		    		'INSERT INTO species_set (species_set_id,genome_db_id) VALUES ('.$self->o('qfo_species_set_id').',#_insert_id_0#)',
		    ],
            },
            -can_be_empty  => 1,
		-wait_for => [ 'check_genome_reuse', 'copy_genomedb' ],
		-flow_into => [ 'store_members_seq' ],    # n_new_species
        },


        {   -logic_name => 'store_members_seq',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FromScratch::StoreMembersSequence',
            -parameters => {
                'data_dir'  => $self->o('data_dir'),
            },
            -can_be_empty  => 1,
            -hive_capacity => 4,
		-wait_for => [ 'subset_table_reuse', 'subset_member_table_reuse', 'member_table_reuse', 'sequence_table_reuse' ],
		-flow_into => [ 'paf_create_empty_table' ],   # n_new_species
        },

        {   -logic_name => 'paf_create_empty_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'CREATE TABLE IF NOT EXISTS peptide_align_feature_#species_name#_#genome_db_id# like peptide_align_feature',
                            'ALTER TABLE peptide_align_feature_#species_name#_#genome_db_id# DISABLE KEYS',
                ],
            },
            -can_be_empty  => 1,
		-flow_into => [ 'dump_subset_create_blastdb' ],   # n_new_species
        },


# ---------------------------------------------[load species tree]-------------------------------------------------------------------

        {   -logic_name => 'store_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
		    'sql'           => [
		    		'INSERT INTO method_link (method_link_id,type,class) VALUES ('.$self->o('qfo_method_link_id').', "QUEST_FOR_ORTHOLOGS_PROTEIN_TREES", "ProteinTree.protein_tree_node")',
		    		'INSERT INTO method_link_species_set (method_link_species_set_id,method_link_id,species_set_id,name) VALUES ('.$self->o('mlss_id').', '.$self->o('qfo_method_link_id').', '.$self->o('qfo_species_set_id').', "protein trees" ) ' 
		    ],
            },
		-flow_into => [ 'make_species_tree' ],  # backbone
        },

        {   -logic_name    => 'copy_ncbi_tables',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
		    'src_db_conn'   => $self->o('master_db'),
            },
            -input_ids => [
                { 'table' => 'ncbi_taxa_name' },
                { 'table' => 'ncbi_taxa_node' },
            ],
            -hive_capacity => 10,
        },


        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
            },
		-wait_for => [ 'copy_ncbi_tables' ],
            -flow_into  => {
		    1 => [ 'hcluster_merge_table_factory' ],  # backbone
                3 => { 'mysql:////gene_tree_root_tag' => { 'node_id' => 1, 'tag' => 'species_tree_string', 'value' => '#species_tree_string#' } },
            },
        },


# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'dump_subset_create_blastdb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::DumpSubsetCreateBlastDB',
            -parameters => {
                'fasta_dir'                 => $self->o('fasta_dir'),
            },
            -batch_size    =>  20,  # they can be really, really short
            -flow_into => {
                1 => [ 'blast_factory' ],   # n_species
            },
        },

        {   -logic_name => 'blast_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'adaptor_name'          => 'SubsetAdaptor',
                'adaptor_method'        => 'fetch_by_description_pattern',
                'method_param_list'     => [ 'gdb:#genome_db_id# % translations' ],
                'object_method'         => 'member_id_list',
                'column_names'          => [ 'member_id' ],
                'fan_branch_code'       => 2,
            },
            -hive_capacity => 10,
            -flow_into => {
                2 => [ 'blastp_with_reuse' ],  # fan n_members
                1 => [ 'hcluster_dump_input_per_genome' ],   # n_species
            },
        },

        {   -logic_name         => 'blastp_with_reuse',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'mlss_id'                   => $self->o('mlss_id'),
                'reuse_db'                  => $self->o('reuse_db'),
                'blast_options'             => $self->o('blast_options'),
                'blast_tmp_dir'             => $self->o('blast_tmp_dir'),
                'fasta_dir'                 => $self->o('fasta_dir'),
                'wublastp_exe'              => $self->o('wublastp_exe'),
            },
            -batch_size    =>  40,
            -hive_capacity => $self->o('blastp_capacity'),
        },

# ---------------------------------------------[clustering step]---------------------------------------------------------------------

        {   -logic_name => 'hcluster_dump_input_per_genome',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare',
            -parameters => {
                'mlss_id'       => $self->o('mlss_id'),
                'outgroups'     => $self->o('outgroups'),
                'cluster_dir'   => $self->o('cluster_dir'),
            },
            -wait_for => [ 'blastp_with_reuse' ],  # funnel n_members
            -hive_capacity => 4,
            -flow_into => {
                1 => [ 'per_genome_clusterset_qc' ],  # n_species
            },
        },

        {   -logic_name    => 'hcluster_merge_inputs',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cluster_dir'               => $self->o('cluster_dir'),
            },
            -input_ids => [
                { 'cmd' => 'cat #cluster_dir#/*.hcluster.txt > #cluster_dir#/hcluster.txt' },
                { 'cmd' => 'cat #cluster_dir#/*.hcluster.cat > #cluster_dir#/hcluster.cat' },
            ],
            -wait_for => [ 'hcluster_dump_input_per_genome' ],
            -hive_capacity => -1,   # to allow for parallelization
        },

        {   -logic_name    => 'hcluster_run',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
                'cluster_dir'                   => $self->o('cluster_dir'),
                'hcluster_exe'                  => $self->o('hcluster_exe'),
                'cmd'                           => '#hcluster_exe# -m #clustering_max_gene_halfcount# -w 0 -s 0.34 -O -C #cluster_dir#/hcluster.cat -o #cluster_dir#/hcluster.out #cluster_dir#/hcluster.txt',
            },
		-input_ids  => [ { } ],
            -wait_for => [ 'hcluster_merge_inputs' ],
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                1 => [ 'hcluster_parse_output' ],   # backbone
            },
            -rc_id => 1,
        },

        {   -logic_name => 'hcluster_parse_output',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput',
            -parameters => {
                'mlss_id'                   => $self->o('mlss_id'),
                'cluster_dir'               => $self->o('cluster_dir'),
            },
            -hive_capacity => -1,
            -flow_into => {
                1 => [ 'overall_clusterset_qc' ],   # backbone 
                2 => [ 'mcoffee' ],                 # fan n_clusters
            },
        },

# ---------------------------------------------[a QC step before main loop]----------------------------------------------------------

        {   -logic_name => 'overall_clusterset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'cluster_dir'               => $self->o('cluster_dir'),
                'groupset_tag'              => 'ClustersetQC',
            },
            -hive_capacity => 3,
            -flow_into => {
                1 => [ 'dummy_wait_alltrees' ],    # backbone
            },
        },

        {   -logic_name => 'per_genome_clusterset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'groupset_tag'              => 'Clusterset',
            },
            -wait_for => [ 'hcluster_parse_output' ],
            -hive_capacity => 3,
            -flow_into => {
                1 => [ 'per_genome_genetreeset_qc' ],   # n_species
            },
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name => 'mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                    => 'cmcoffee',      # presumably, at the moment it refers to the 'initial' method
                'use_exon_boundaries'       => $self->o('use_exon_boundaries'),
                'max_gene_count'            => $self->o('tree_max_gene_count'),
                'mcoffee_exe'               => $self->o('mcoffee_exe'),
                'mafft_exe'                 => $self->o('mafft_exe'),
                'mafft_binaries'            => $self->o('mafft_binaries'),
            },
            -wait_for => [ 'overall_clusterset_qc', 'per_genome_clusterset_qc' ],    # funnel
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -flow_into => {
               -2 => [ 'mcoffee_himem' ],  # RUNLIMIT
               -1 => [ 'mcoffee_himem' ],  # MEMLIMIT
                1 => [ 'njtree_phyml' ],
                3 => [ 'quick_tree_break' ],
            },
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                    => 'cmcoffee',      # presumably, at the moment it refers to the 'initial' method
                'use_exon_boundaries'       => $self->o('use_exon_boundaries'),
                'max_gene_count'            => $self->o('tree_max_gene_count'),
                'mcoffee_exe'               => $self->o('mcoffee_exe'),
                'mafft_exe'                 => $self->o('mafft_exe'),
                'mafft_binaries'            => $self->o('mafft_binaries'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -can_be_empty         => 1,
            -flow_into => {
                1 => [ 'njtree_phyml' ],
                3 => [ 'quick_tree_break' ],
            },
            -rc_id => 2,
        },

        {   -logic_name => 'njtree_phyml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 0,
                'bootstrap'                 => 1,
                'check_split_genes'         => 0,
                'use_genomedb_id'           => $self->o('use_genomedb_id'),
                'treebest_exe'              => $self->o('treebest_exe'),
            },
            -hive_capacity        => $self->o('njtree_phyml_capacity'),
            -failed_job_tolerance => 5,
		-wait_for => [ 'make_species_tree' ],
            -flow_into => {
                1 => [ 'ortho_tree' ],
                2 => [ 'njtree_phyml' ],
            },
        },

        {   -logic_name => 'ortho_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OrthoTree',
            -parameters => {
                'use_genomedb_id'           => $self->o('use_genomedb_id'),
            },
            -hive_capacity        => $self->o('ortho_tree_capacity'),
            -failed_job_tolerance => 5,
            -flow_into => {
            },
        },

        {   -logic_name => 'quick_tree_break',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak',
            -parameters => {
                'mlss_id'           => $self->o('mlss_id'),
                'quicktree_exe'     => $self->o('quicktree_exe'),
                'sreformat_exe'     => $self->o('sreformat_exe'),
            },
            -hive_capacity        => 1, # this one seems to slow the whole loop down; why can't we have any more of these?
            -can_be_empty         => 1,
            -failed_job_tolerance => 5,
            -flow_into => {
                1 => [ 'other_paralogs' ],
                2 => [ 'mcoffee' ],
            },
        },


        {   -logic_name => 'dummy_wait_alltrees',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters => {},
            -wait_for => [ 'mcoffee', 'mcoffee_himem', 'njtree_phyml', 'ortho_tree', 'quick_tree_break' ],    # funnel n_clusters
		-flow_into => [ 'overall_genetreeset_qc' ],  # backbone
        },


        {   -logic_name => 'other_paralogs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OtherParalogs',
            -parameters => { },
            -wait_for => [ 'dummy_wait_alltrees' ],
            -hive_capacity        => $self->o('other_paralogs_capacity'),
            -failed_job_tolerance => 5,
        },

# ---------------------------------------------[a QC step after main loop]----------------------------------------------------------

        {   -logic_name => 'overall_genetreeset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'cluster_dir'               => $self->o('cluster_dir'),
                'groupset_tag'              => 'GeneTreesetQC',
            },
            -hive_capacity => 3,
        },

        {   -logic_name => 'per_genome_genetreeset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'groupset_tag'              => 'GeneTreeset',
            },
            -wait_for => [ 'dummy_wait_alltrees' ],
            -hive_capacity => 3,
        },


    ];
}

1;

