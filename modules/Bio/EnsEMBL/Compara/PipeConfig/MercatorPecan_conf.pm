
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf -password <your_password> -mlss_id <your_current_Pecan_mlss_id> --ce_mlss_id <constrained_element_mlss_id> --cs_mlss_id <conservation_score_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

    The PipeConfig file for MercatorPecan pipeline that should automate most of the pre-execution tasks.

    FYI: it took (3.7 x 24h) to perform the full production run for EnsEMBL release 62.

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones


    # parameters that are likely to change from execution to another:
	#pecan mlss_id
#       'mlss_id'               => 522,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        #constrained element mlss_id
#       'ce_mlss_id'            => 523,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
	#conservation score mlss_id
#       'cs_mlss_id'            => 50029, # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'release'               => '70',
        'release_suffix'        => '',    # an empty string by default, a letter otherwise
        'ensembl_cvs_root_dir'  => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
	'dbname'                => $ENV{USER}.'_pecan_20way_'.$self->o('release').$self->o('release_suffix'),
        'work_dir'              => '/lustre/scratch109/ensembl/' . $ENV{'USER'} . '/scratch/hive/release_' . $self->o('rel_with_suffix') . '/' . $self->o('dbname'),
	'do_not_reuse_list'     => [ 112, 132 ],     # genome_db_ids of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.
#	'do_not_reuse_list'     => [ 87 ],     # names of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.

    # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
        'pipeline_name'         => 'PECAN_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
        'blastdb_dir'           => $self->o('work_dir') . '/blast_db',  
        'mercator_dir'          => $self->o('work_dir') . '/mercator',  

    # blast parameters:
	'blast_params'          => "-num_alignments 20 -seg 'yes' -best_hit_overhang 0.2 -best_hit_score_edge 0.1 -use_sw_tback",
        'blast_capacity'        => 100,

    #location of full species tree, will be pruned
        'species_tree_file'     => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh', 

    #master database
        'master_db_name' => 'sf5_ensembl_compara_master', 

    #update_max_alignment_length
    'quick' => 1, #use quick method for calculating the max_alignment_length (genomic_align_block->length 
                  #instead of genomic_align->dnafrag_end - genomic_align->dnafrag_start + 1

    # Mercator default parameters
    'strict_map'        => 1,
#    'cutoff_score'     => 100,   #not normally defined
#    'cutoff_evalue'    => 1e-5, #not normally defined
    'method_link_type'  => "SYNTENY",
    'maximum_gap'       => 50000,
    'input_dir'         => $self->o('work_dir').'/mercator',
    'all_hits'          => 0,

    #Pecan default parameters
    'max_block_size'    => 1000000,
    'java_options'      => '-server -Xmx1000M',
    'java_options_mem1' => '-server -Xmx2500M -Xms2000m',
    'java_options_mem2' => '-server -Xmx4500M -Xms4000m',
    'java_options_mem3' => '-server -Xmx6500M -Xms6000m',
#    'jar_file'          => '/nfs/users/nfs_k/kb3/src/benedictpaten-pecan-973a28b/lib/pecan.jar',
    'jar_file'          => '/software/ensembl/compara/pecan/pecan_v0.8.jar',

    #Gerp default parameters
    'window_sizes'      => "[1,10,100,500]",
    'gerp_version'      => 2.1,

	    
    #Location of executables (or paths to executables)
    'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl", 
    'gerp_exe_dir'              => '/software/ensembl/compara/gerp/GERPv2.1',
    'mercator_exe'              => '/software/ensembl/compara/mercator',
    'blast_exe_dir'             => '/software/ensembl/compara/ncbi-blast-2.2.23+/bin',


    # connection parameters to various databases:

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                    
            -dbname => $ENV{'USER'}.'_pecan_20way_'.$self->o('rel_with_suffix'),
        },

        'master_db' => {                        # the master database for synchronization of various ids
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
	    -driver => 'mysql',
        },

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'ens-staging1',
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

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },
        # "production mode"
       'reuse_core_sources_locs'   => [ $self->o('livemirror_loc') ],
       'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
       'prev_release'              => 0,   # 0 is the default and it means "take current release number and subtract 1"

       'reuse_db' => {   # usually previous pecan production database
           -host   => 'compara1',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'kb3_pecan_19way_68',
	   -driver => 'mysql',
        },

	#Testing mode
        'reuse_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ensdb-archive',
            -port   => 5304,
            -user   => 'ensro',
            -pass   => '',
            -db_version => '61'
        },

        'curr_loc' => {                   # general location of the current release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -db_version => '62'
        },
#        'reuse_core_sources_locs'   => [ $self->o('reuse_loc') ],
#        'curr_core_sources_locs'    => [ $self->o('curr_loc'), ],
#        'prev_release'              => 61,   # 0 is the default and it means "take current release number and subtract 1"
#        'reuse_db' => {   # usually previous production database
#           -host   => 'compara4',
#           -port   => 3306,
#           -user   => 'ensro',
#           -pass   => '',
#           -dbname => 'kb3_pecan_19way_61',
#        },
    };
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('blastdb_dir'),
        'mkdir -p '.$self->o('mercator_dir'),
        'lfs setstripe '.$self->o('blastdb_dir').' -c -1',    # stripe
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
	 '100Mb' =>  { 'LSF' => '-C0 -M100000 -R"select[mem>100] rusage[mem=100]"' },  
	 '1Gb' =>    { 'LSF' => '-C0 -M1000000 -R"select[mem>1000] rusage[mem=1000]"' },  
	 '1.8Gb' =>  { 'LSF' => '-C0 -M1800000 -R"select[mem>1800] rusage[mem=1800]"' },  
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600000 -R"select[mem>3600] rusage[mem=3600]"' },
         '7.5Gb' =>  { 'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' }, 
         '11.4Gb' => { 'LSF' => '-C0 -M11400000 -R"select[mem>11400] rusage[mem=11400]"' }, 
         '14Gb' =>   { 'LSF' => '-C0 -M14000000 -R"select[mem>14000] rusage[mem=14000]"' }, 
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

# ---------------------------------------------[Turn all tables except 'genome_db' to InnoDB]---------------------------------------------
	    {   -logic_name => 'innodbise_table_factory',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='meta' AND engine='MyISAM' ",
				'fan_branch_code' => 2,
			       },
		-input_ids => [{}],
		-flow_into => {
			       2 => [ 'innodbise_table'  ],
			       1 => [ 'populate_new_database' ],
			      },
		-rc_name => '100Mb',
	    },

	    {   -logic_name    => 'innodbise_table',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
				   'sql'         => "ALTER TABLE #table_name# ENGINE='InnoDB'",
				  },
		-hive_capacity => 1,
		-can_be_empty  => 1,
		-rc_name => '100Mb',
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'master'         => $self->o('master_db_name'),
				  'new_db'         => $self->o('dbname'),
				  'mlss_id'        => $self->o('mlss_id'),
				  'ce_mlss_id'     => $self->o('ce_mlss_id'),
				  'cs_mlss_id'     => $self->o('cs_mlss_id'),
				  'cmd'            => "#program# --master " . $self->dbconn_2_url('master_db') . " --new " . $self->dbconn_2_url('pipeline_db') . " --mlss #mlss_id# --mlss #ce_mlss_id# --mlss #cs_mlss_id# ",
				 },
	       -wait_for  => [ 'innodbise_table' ],
	       -flow_into => {
			      1 => [ 'set_mlss_tag' ],
			     },
		-rc_name => '1Gb',
	    },

# -------------------------------------------[Set conservation score method_link_species_set_tag ]------------------------------------------
            { -logic_name => 'set_mlss_tag',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
              -parameters => {
                              'sql' => [ 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (' . $self->o('cs_mlss_id') . ', "msa_mlss_id", ' . $self->o('mlss_id') . ')' ],
                             },
              -flow_into => {
                             1 => [ 'set_internal_ids' ],
                            },
              -rc_name => '100Mb',
            },

# ------------------------------------------------------[Set internal ids ]---------------------------------------------------------------
	    {   -logic_name => 'set_internal_ids',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'mlss_id' => $self->o('mlss_id'),
				'sql'   => [
					    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr(($mlss_id * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr(($mlss_id * 10**10) + 1)expr#',
					   ],
			       },
		-flow_into => {
			       1 => [ 'load_genomedb_factory' ],
			      },
		-rc_name => '100Mb',
	    },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
                'mlss_id'       => $self->o('mlss_id'),

                'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', ['fetch_by_dbID', '#mlss_id#'], 'species_set_obj', 'genome_dbs'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },

                'fan_branch_code'       => 2,
            },
            -flow_into => {
                2 => [ 'load_genomedb' ],
		1 => [ 'load_genomedb_funnel' ],    # backbone
            },
	    -rc_name => '100Mb',
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
	    -rc_name => '100Mb',
        },

	{   -logic_name => 'load_genomedb_funnel',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -wait_for => [ 'load_genomedb' ],
            -flow_into => {
                1 => [ 'accumulate_reuse_ss', 'generate_reuse_ss' ],  # "backbone"
            },
	    -rc_name => '100Mb',
        },


# ---------------------------------------------[generate an empty species_set for reuse (to be filled in at a later stage) ]---------

         {   -logic_name => 'generate_reuse_ss',
             -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
             -parameters => {
                 'sql' => [  "INSERT INTO species_set (genome_db_id) SELECT genome_db_id FROM genome_db LIMIT 1",   # inserts a dummy pair (auto_increment++, any_genome_db_id) into the table
                             "DELETE FROM species_set WHERE species_set_id=#_insert_id_0#", # will delete the row previously inserted, but keep the auto_increment
                 ],
             },
             -flow_into => {
                 2 => { 'mysql:////meta' => { 'meta_key' => 'reuse_ss_id', 'meta_value' => '#_insert_id_0#' } },     # dynamically record it as a pipeline-wide parameter
             },
	    -rc_name => '100Mb',
         },


# ---------------------------------------------[load species tree]-------------------------------------------------------------------

	    {   -logic_name    => 'make_species_tree',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
		-parameters    => { 
				   'mlss_id' => $self->o('mlss_id'),
				  },
		-input_ids     => [
				   {'blength_tree_file' => $self->o('species_tree_file'), 'newick_format' => 'simple' }, #species_tree
				  ],
		-hive_capacity => -1,   # to allow for parallelization
		-wait_for => [ 'load_genomedb_funnel' ],
		-flow_into => {
			       4 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
			      },
		-rc_name => '100Mb',
	    },

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
		'reuse_db'      => $self->o('reuse_db'),
                'registry_dbs'  => $self->o('reuse_core_sources_locs'),
                'release'       => $self->o('release'),
                'prev_release'  => $self->o('prev_release'),
		'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -hive_capacity => 10,    # allow for parallel execution
	    -wait_for => [ 'generate_reuse_ss', 'make_species_tree' ],
            -flow_into => {
                2 => { 
		      'check_reuse_db'            => undef,
                      'mysql:////species_set'     => { 'genome_db_id' => '#genome_db_id#', 'species_set_id' => '#reuse_ss_id#' },
                },
                3 => [ 'load_fresh_members', 'paf_create_empty_table' ], #Fresh tables
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name    => 'accumulate_reuse_ss',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',     # a non-standard use of JobFactory for iterative insertion
            -parameters => {
                'inputquery'      => 'SELECT "reuse_ss_csv" meta_key, GROUP_CONCAT(genome_db_id) meta_value FROM species_set WHERE species_set_id=#reuse_ss_id#',
                'fan_branch_code' => 3,
            },
            -wait_for => [ 'check_reusability' ],
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                3 => [ 'mysql:////meta' ],
            },
	    -rc_name => '100Mb',
        },

# ---------------------------------------------[reuse members and pafs]--------------------------------------------------------------

	{   -logic_name => 'check_reuse_db',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::CheckReuseDB',
	    -parameters => {
		'reuse_url'   => $self->dbconn_2_url('reuse_db'),
	    },
	    -wait_for => [ 'accumulate_reuse_ss' ], # to make sure some fresh members won't start because they were dataflown first (as this analysis can_be_empty)
            -hive_capacity => -1,   # to allow for parallelization
	    -can_be_empty  => 1,
            -flow_into => {
                1 => { 
                       'paf_table_reuse'           => undef,
                       'sequence_table_reuse'      => undef,
                },
		3 => [ 'load_fresh_members', 'paf_create_empty_table' ],
            },
	    -rc_name => '100Mb',
        },

        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'    => $self->o('reuse_db'),
                'inputquery' => 'SELECT s.* FROM sequence s JOIN member USING (sequence_id) WHERE genome_db_id = #genome_db_id#',
			    'fan_branch_code' => 2,
            },
            -hive_capacity => 4,
            -can_be_empty  => 1,
            -flow_into => {
		 1 => [ 'member_table_reuse' ],    # n_reused_species
		 2 => 'mysql:////sequence',
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name => 'member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
		'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'member',
                'where'         => 'genome_db_id = #genome_db_id#',
		'mode'          => 'insertignore',
            },
            -hive_capacity => 4,
            -can_be_empty  => 1,
            -flow_into => {
		 1 => [ 'reuse_dump_subset_fasta' ],   # n_reused_species
            },
	    -rc_name => '100Mb',
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'peptide_align_feature_#per_genome_suffix#',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
            },
	    -wait_for   => [ 'accumulate_reuse_ss' ],     # have to wait until reuse_ss_csv is computed
            -hive_capacity => 4,
            -can_be_empty  => 1,
	    -rc_name => '100Mb',
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'paf_create_empty_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'CREATE TABLE IF NOT EXISTS peptide_align_feature_#per_genome_suffix# like peptide_align_feature',
                            'ALTER TABLE peptide_align_feature_#per_genome_suffix# ADD KEY hmember_hit (hmember_id, hit_rank)',
                            'ALTER TABLE peptide_align_feature_#per_genome_suffix# DISABLE KEYS',
                ],
            },
            -can_be_empty  => 1,
	    -rc_name => '100Mb',
        },

        {   -logic_name => 'load_fresh_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {'coding_exons' => 1,
			    'min_length' => 20 },
            -wait_for => [ 'check_reuse_db', 'paf_create_empty_table', 'accumulate_reuse_ss', 'member_table_reuse', 'sequence_table_reuse' ],
            -hive_capacity => -1,
            -can_be_empty  => 1,
            -flow_into => {
                 1 => [ 'fresh_dump_subset_fasta' ],
            },
	    -rc_name => '1.8Gb',
        },

# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'reuse_dump_subset_fasta',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpSubsetIntoFasta',
            -parameters => {
                 'fasta_dir'                 => $self->o('blastdb_dir'),
            },
             -batch_size    =>  20,  # they can be really, really short
	    -can_be_empty  => 1,
            -wait_for  => [ 'member_table_reuse', 'sequence_table_reuse' ],   # act as a funnel
            -flow_into => {
                1 => [ 'make_blastdb' ],
                2 => [ 'blast_factory' ],
            },
	    -rc_name => '1Gb',
        },
        {   -logic_name => 'fresh_dump_subset_fasta',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpSubsetIntoFasta',
            -parameters => {
                 'fasta_dir'                 => $self->o('blastdb_dir'),
            },
             -batch_size    =>  20,  # they can be really, really short
            -wait_for  => [ 'load_fresh_members' ],   # act as a funnel
            -flow_into => {
                1 => [ 'make_blastdb' ],
                2 => [ 'blast_factory' ],
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
		'fasta_dir'     => $self->o('blastdb_dir'),
		'blast_bin_dir' => $self->o('blast_exe_dir'),
                'cmd' => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_dir#/make_blastdb.log -in #fasta_name#',
            },
	    -wait_for  => [ 'reuse_dump_subset_fasta' , 'fresh_dump_subset_fasta' ],
	    -rc_name => '100Mb',
        },

       {   -logic_name => 'blast_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastFactory',
            -parameters => {
                'step'            => 1000,
            },
	    -hive_capacity => 10,
	    -wait_for => [ 'make_blastdb' ],
            -flow_into => {
                2 => [ 'mercator_blast' ],
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name    => 'mercator_blast',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastAndParsePAF',
            -parameters    => {
                'blast_params' => $self->o('blast_params'),
		'mlss_id'      => $self->o('mlss_id'),
		'fasta_dir'    => $self->o('blastdb_dir'),
            },
	    -wait_for => [ 'paf_table_reuse' ],
            -batch_size => 10,
            -hive_capacity => $self->o('blast_capacity'),
	    -rc_name => '1.8Gb',
        },


# ---------------------------------------------[mercator]---------------------------------------------------------------

         {   -logic_name => 'mercator_file_factory',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory',
             -parameters => { 
			     'mlss_id' => $self->o('mlss_id'),
			    },
	    -input_ids     => [{}],
            -hive_capacity => 1,
	    -wait_for  => [ 'mercator_blast' ],
	    -flow_into => { 
			    1 => { 'mercator' => undef },
			    2 => ['dump_mercator_files'],
			   },
	    -rc_name => '100Mb',
         },

         {   -logic_name => 'dump_mercator_files',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpMercatorFiles',
             -parameters => { 'maximum_gap' => $self->o('maximum_gap'),
			      'input_dir'   => $self->o('input_dir'),
			      'all_hits'    => $self->o('all_hits'),
			    },
             -hive_capacity => -1,
	     -rc_name => '1Gb',
         },

         {   -logic_name => 'mercator',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Mercator',
             -parameters => {'mlss_id'   => $self->o('mlss_id'),
			     'input_dir' => $self->o('input_dir'),
			     'method_link_type' => $self->o('method_link_type'),
			    },
             -hive_capacity => 1,
	     -rc_name => '3.6Gb',
	     -wait_for => [ 'dump_mercator_files' ],
             -flow_into => {
                 1 => [ 'pecan' ],
             },
         },

# ---------------------------------------------[pecan]---------------------------------------------------------------------

         {   -logic_name => 'pecan',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options'),
                 'mlss_id'                    => $self->o('mlss_id'),
		 'jar_file'                   => $self->o('jar_file'),
             },
             -max_retry_count => 1,
             -hive_capacity => 500,
             -flow_into => {
                 1 => [ 'gerp' ],
		 2 => [ 'pecan_mem1'], #retry with more heap memory
		-1 => [ 'pecan_mem1'], #MEMLIMIT (pecan didn't fail, but lsf did)
		-2 => [ 'pecan_mem1'], #RUNLIMIT
             },
	    -rc_name => '1.8Gb',
         },

         {   -logic_name => 'pecan_mem1',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options_mem1'),
                 'mlss_id'                    => $self->o('mlss_id'),
		 'jar_file'                   => $self->o('jar_file'),
             },
 	     -can_be_empty  => 1,
             -max_retry_count => 1,
	     -rc_name => '7.5Gb',
             -hive_capacity => 500,
             -flow_into => {
                 1 => [ 'gerp' ],
		 2 => [ 'pecan_mem2'], #retry with even more heap memory
		-2 => [ 'pecan_mem2'], #RUNLIMIT
             },
         },
         {   -logic_name => 'pecan_mem2',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options_mem2'),
                 'mlss_id'                    => $self->o('mlss_id'),
                 'jar_file'                   => $self->o('jar_file'),
             },
	     -can_be_empty  => 1,
             -max_retry_count => 1,
	     -rc_name => '11.4Gb',
             -hive_capacity => 500,
             -flow_into => {
                 1 => [ 'gerp' ],
		 2 => [ 'pecan_mem3'], #retry with even more heap memory
		-2 => [ 'pecan_mem3'], #RUNLIMIT
             },
         },
         {   -logic_name => 'pecan_mem3',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options_mem3'),
                 'mlss_id'                    => $self->o('mlss_id'),
                 'jar_file'                   => $self->o('jar_file'),
             },
	     -can_be_empty  => 1,
             -max_retry_count => 1,
	     -rc_name => '14Gb',
             -hive_capacity => 500,
             -flow_into => {
                 1 => [ 'gerp' ],
             },
         },
# ---------------------------------------------[gerp]---------------------------------------------------------------------

         {   -logic_name    => 'gerp',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
             -parameters    => {
		 'program_version' => $self->o('gerp_version'),
                 'window_sizes'    => $self->o('window_sizes'),
		 'gerp_exe_dir'    => $self->o('gerp_exe_dir'),
                 'mlss_id'         => $self->o('mlss_id'),  #to retrieve species_tree from mlss_tag table
#                 'constrained_element_method_link_type' => $self->o('constrained_element_type'),
             },
#             -wait_for => [ 'mercator' ],
             -hive_capacity => 500,  
             -flow_into => {
		 2 => [ 'gerp_himem'], #retry with more memory
             },
	     -rc_name => '1Gb',
         },
         {   -logic_name    => 'gerp_himem',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
             -parameters    => {
		 'program_version' => $self->o('gerp_version'),
                 'window_sizes'    => $self->o('window_sizes'),
		 'gerp_exe_dir'    => $self->o('gerp_exe_dir'),
                 'mlss_id'         => $self->o('mlss_id'),  #to retrieve species_tree from mlss_tag table
             },
 	    -can_be_empty  => 1,
            -hive_capacity => 500,  
	     -rc_name => '1.8Gb',
         },
 	 {  -logic_name => 'update_max_alignment_length',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	    -parameters => { 
			    'quick'                      => $self->o('quick'),
			    'method_link_species_set_id' => $self->o('mlss_id'),

			   },
            -input_ids => [{}],
	    -wait_for => [ 'pecan', 'pecan_mem1', 'pecan_mem2', 'pecan_mem3','gerp', 'gerp_himem'],
	    -rc_name => '100Mb',
	 },

# ---------------------------------------------[healthcheck]---------------------------------------------------------------------
        {   -logic_name    => 'conservation_score_healthcheck',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
             -parameters    => {
             },
             -input_ids => [
                 { 'test' => 'conservation_jobs', 'logic_name' => 'Gerp','method_link_type' => 'PECAN',},
		 { 'test' => 'conservation_scores', 'method_link_species_set_id' => $self->o('cs_mlss_id')},
             ],
             -wait_for => ['update_max_alignment_length' ],
             -hive_capacity => -1,   # to allow for parallelization
	    -rc_name => '100Mb',
	},

    ];

}

1;

