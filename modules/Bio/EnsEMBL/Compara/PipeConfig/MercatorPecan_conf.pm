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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf -password <your_password> -mlss_id <your_current_Pecan_mlss_id> --ce_mlss_id <constrained_element_mlss_id> --cs_mlss_id <conservation_score_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

    The PipeConfig file for MercatorPecan pipeline that should automate most of the pre-execution tasks.

    FYI: it took (3.7 x 24h) to perform the full production run for EnsEMBL release 62.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

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
        'release'               => '74',
        'release_suffix'        => '',    # an empty string by default, a letter otherwise
        'ensembl_cvs_root_dir'  => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
	'dbname'                => $ENV{USER}.'_pecan_21way_'.$self->o('release').$self->o('release_suffix'),
        'work_dir'              => '/lustre/scratch109/ensembl/' . $ENV{'USER'} . '/scratch/hive/release_' . $self->o('rel_with_suffix') . '/' . $self->o('dbname'),
#	'do_not_reuse_list'     => [ ],     # genome_db_ids of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.
	'do_not_reuse_list'     => [ 142 ],     # names of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.

        'species_set' => undef, 

    # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
        'pipeline_name'         => 'PECAN_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
        'blastdb_dir'           => $self->o('work_dir') . '/blast_db',  
        'mercator_dir'          => $self->o('work_dir') . '/mercator',  

    # blast parameters:
	'blast_params'          => "-seg 'yes' -best_hit_overhang 0.2 -best_hit_score_edge 0.1 -use_sw_tback",
        'blast_capacity'        => 100,

    #location of full species tree, will be pruned
        'species_tree_file'     => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh', 

    #master database
        'master_db_name' => 'sf5_ensembl_compara_master', 

    #update_max_alignment_length
    'quick' => 1, #use quick method for calculating the max_alignment_length (genomic_align_block->length 
                  #instead of genomic_align->dnafrag_end - genomic_align->dnafrag_start + 1

    'do_transactions'   => 1, #use transactions in Pecan and Gerp modules


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
    'blast_bin_dir'             => '/software/ensembl/compara/ncbi-blast-2.2.27+/bin',
    'exonerate_exe'             => '/software/ensembl/compara/exonerate/exonerate',

    'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
    'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

    #
    #Default statistics
    #
    'skip_multiplealigner_stats' => 0, #skip this module if set to 1
    'bed_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/pecan/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',
    'output_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/pecan/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',

    # connection parameters to various databases:

        'host'        => 'compara5',            #separate parameter to use the resources aswell
        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => $self->o('host'),
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                    
            -dbname => $ENV{'USER'}.'_pecan_21way_'.$self->o('rel_with_suffix'),
	    -driver => 'mysql',
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

       'reuse_db' => {   # usually previous pecan production database
           -host   => 'compara3',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'kb3_pecan_20way_71',
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
#        'reuse_db' => {   # usually previous production database
#           -host   => 'compara4',
#           -port   => 3306,
#           -user   => 'ensro',
#           -pass   => '',
#           -dbname => 'kb3_pecan_19way_61',
#        },


     #
     #Resource requirements
     #
     'memory_suffix' => "", #temporary fix to define the memory requirements in resource_classes
     'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
     'aligner_capacity' => 2000,

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
        'which lfs && lfs getstripe '.$self->o('blastdb_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('blastdb_dir').' -c -1 || echo "Striping is not available on this system" ',
        'mkdir -p '.$self->o('output_dir'), #Make dump_dir directory
        'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
     ];
}


sub resource_classes {
    my ($self) = @_;
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
	 '100Mb' =>  { 'LSF' => '-C0 -M100' . $self->o('memory_suffix') .' -R"select[mem>100] rusage[mem=100]"' }, 
	 '1Gb' =>    { 'LSF' => '-C0 -M1000' . $self->o('memory_suffix') .' -R"select[mem>1000] rusage[mem=1000]"' },  
	 '1.8Gb' =>  { 'LSF' => '-C0 -M1800' . $self->o('memory_suffix') .' -R"select[mem>1800 && '. $self->o('dbresource'). '<'.$self->o('aligner_capacity').'] rusage[mem=1800,'.$self->o('dbresource').'=10:duration=3]"' },  
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600' . $self->o('memory_suffix') .' -R"select[mem>3600] rusage[mem=3600]"' },
         '7.5Gb' =>  { 'LSF' => '-C0 -M7500' . $self->o('memory_suffix') .' -R"select[mem>7500] rusage[mem=7500]"' }, 
         '11.4Gb' => { 'LSF' => '-C0 -M11400' . $self->o('memory_suffix') .' -R"select[mem>11400] rusage[mem=11400]"' }, 
         '14Gb' =>   { 'LSF' => '-C0 -M14000' . $self->o('memory_suffix') .' -R"select[mem>14000] rusage[mem=14000]"' }, 
         'gerp' =>   { 'LSF' => '-C0 -M1000' . $self->o('memory_suffix') .' -R"select[mem>1000 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1000,'.$self->o('dbresource').'=10:duration=3]"' },
         'higerp' =>   { 'LSF' => '-C0 -M1800' . $self->o('memory_suffix') .' -R"select[mem>1800 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1800,'.$self->o('dbresource').'=10:duration=3]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
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
               -input_ids => [{}],
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
					    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
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
                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator', 'has_karyotype' => 'has_karyotype', 'is_high_coverage' => 'is_high_coverage' },

                'fan_branch_code'       => 2,
            },
            -flow_into => {
                '2->A' => [ 'load_genomedb' ],
                'A->1' => [ 'create_mlss_ss' ],
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

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
		'reuse_db'      => $self->o('reuse_db'),
                'registry_dbs'  => $self->o('reuse_core_sources_locs'),
                'release'       => $self->o('release'),
		'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -hive_capacity => 10,    # allow for parallel execution
            -flow_into => {
                2 => {'check_reuse_db'                  => undef, 
                      ':////accu?reused_gdb_ids=[]'     => { 'reused_gdb_ids' => '#genome_db_id#'} 
                     },
                3 => { ':////accu?nonreused_gdb_ids=[]' => { 'nonreused_gdb_ids' => '#genome_db_id#'} },
            },
	    -rc_name => '1Gb',
        },

	{   -logic_name => 'check_reuse_db',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::CheckReuseDB',
	    -parameters => {
		'reuse_url'   => $self->dbconn_2_url('reuse_db'),
	    },
	    -rc_name => '1Gb',
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS',
            -parameters => {
                'mlss_id'   => $self->o('mlss_id'),
                'master_db' => $self->o('master_db'),
            },
            -flow_into => [ 'make_species_tree' ],
            -meadow_type    => 'LOCAL',
        },

        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => { 
                               'mlss_id' => $self->o('mlss_id'),
                               'blength_tree_file' => $self->o('species_tree_file'),
                               'newick_format' => 'simple',
                              },
            -flow_into => {
                           1 => [ 'genome_reuse_factory' ],
                          },
            -rc_name => '100Mb',
        },

# ---------------------------------------------[reuse members and pafs]--------------------------------------------------------------

        {   -logic_name => 'genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #reuse_ss_id#',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                '2->A' => [ 'sequence_table_reuse' ],
                'A->1' => [ 'genome_loadfresh_factory' ],
            },
        },


        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'    => $self->o('reuse_db'),
                'inputquery' => 'SELECT s.* FROM sequence s JOIN seq_member USING (sequence_id) WHERE genome_db_id = #genome_db_id#',
			    'fan_branch_code' => 2,
            },
            -hive_capacity => 4,
            -flow_into => {
		 1 => [ 'seq_member_table_reuse' ],    # n_reused_species
		 2 => [ 'mysql:////sequence' ],
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name => 'seq_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'seq_member',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'gene_member_table_reuse' ],
            },
        },

        {   -logic_name => 'gene_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'gene_member',
                'where'         => 'genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'paf_table_reuse' ],
            },
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'peptide_align_feature_#genome_db_id#',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
            },
            -hive_capacity => 4,
	    -rc_name => '100Mb',
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'genome_loadfresh_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'        => 'SELECT genome_db_id, name FROM species_set JOIN genome_db USING (genome_db_id) WHERE species_set_id = #nonreuse_ss_id# AND locator LIKE "Bio::EnsEMBL::DBSQL::DBAdaptor/%"',
                'fan_branch_code'   => 2,
            },
            -flow_into => {
                '2->A' => [ 'paf_create_empty_table' ],
                'A->1' => [ 'blastdb_factory' ],
            },
        },

        {   -logic_name => 'paf_create_empty_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'CREATE TABLE IF NOT EXISTS peptide_align_feature_#genome_db_id# like peptide_align_feature',
                            'ALTER TABLE peptide_align_feature_#genome_db_id# ADD KEY hmember_hit (hmember_id, hit_rank)',
                            'ALTER TABLE peptide_align_feature_#genome_db_id# DISABLE KEYS',
               ],
            },
            -flow_into => {
                 1 => [ 'load_fresh_members' ],
            },
	    -rc_name => '100Mb',
        },

        {   -logic_name => 'load_fresh_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {'coding_exons' => 1,
			    'min_length' => 20 },
	    -rc_name => '1.8Gb',
        },


# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'blastdb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                'fan_branch_code'       => 2,
            },
            -rc_name       => '100Mb',
            -flow_into  => {
                '2->A'  => [ 'fresh_dump_subset_fasta' ],
                'A->1'  => [ 'blast_species_factory' ],
            },
        },

        {   -logic_name => 'fresh_dump_subset_fasta',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',
            -parameters => {
                 'fasta_dir'                 => $self->o('blastdb_dir'),
            },
             -batch_size    =>  20,  # they can be really, really short
            -flow_into => {
                1 => [ 'make_blastdb' ],
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'fasta_dir'     => $self->o('blastdb_dir'),
                'blast_bin_dir' => $self->o('blast_bin_dir'),
                'cmd'           => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_dir#/make_blastdb.log -in #fasta_name#',
            },
	    -rc_name => '100Mb',
        },

        {   -logic_name => 'blast_species_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                'fan_branch_code'       => 2,
            },
            -flow_into  => {
                '2->A'  => [ 'blast_factory' ],
                'A->1'  => [ 'mercator_file_factory' ],
            },
        },

       {   -logic_name => 'blast_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastFactory',
            -parameters => {
                'step'            => 1000,
            },
	    -hive_capacity => 10,
            -flow_into => {
                2 => [ 'mercator_blast' ],
            },
	    -rc_name => '1Gb',
        },

        {   -logic_name    => 'mercator_blast',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastAndParsePAF',
            -parameters    => {
                'blast_params'      => $self->o('blast_params'),
                'blast_bin_dir'     => $self->o('blast_bin_dir'),
                'do_transactions' => 1,
		'mlss_id'      => $self->o('mlss_id'),
		'fasta_dir'    => $self->o('blastdb_dir'),
            },
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
            -hive_capacity => 1,
	    -flow_into => { 
			    'A->1' => { 'mercator' => undef },
			    '2->A' => ['dump_mercator_files'],
			   },
	    -rc_name => '100Mb',
         },

         {   -logic_name => 'dump_mercator_files',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpMercatorFiles',
             -parameters => { 'maximum_gap' => $self->o('maximum_gap'),
			      'input_dir'   => $self->o('input_dir'),
			      'all_hits'    => $self->o('all_hits'),
			    },
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
             -flow_into => {
                 '2->A' => [ 'pecan' ],
                 'A->1' => [ 'update_max_alignment_length' ],
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
                 'exonerate'                  => $self->o('exonerate_exe'),
                 'do_transactions'            => $self->o('do_transactions'),
             },
             -max_retry_count => 1,
             -priority => 1,
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
                 'exonerate'                  => $self->o('exonerate_exe'),
                 'do_transactions'            => $self->o('do_transactions'),
             },
             -max_retry_count => 1,
             -priority => 1,
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
                 'exonerate'                  => $self->o('exonerate_exe'),
                 'do_transactions'            => $self->o('do_transactions'),
             },
             -max_retry_count => 1,
             -priority => 1,
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
                 'exonerate'                  => $self->o('exonerate_exe'),
                 'do_transactions'            => $self->o('do_transactions'),
             },
             -max_retry_count => 1,
             -priority => 1,
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
                 'do_transactions' => $self->o('do_transactions'),
#                 'constrained_element_method_link_type' => $self->o('constrained_element_type'),
             },
             -hive_capacity => 500,  
             -flow_into => {
		 -1 => [ 'gerp_himem'], #retry with more memory
             },
	     -rc_name => 'gerp',
         },
         {   -logic_name    => 'gerp_himem',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
             -parameters    => {
		 'program_version' => $self->o('gerp_version'),
                 'window_sizes'    => $self->o('window_sizes'),
		 'gerp_exe_dir'    => $self->o('gerp_exe_dir'),
                 'mlss_id'         => $self->o('mlss_id'),  #to retrieve species_tree from mlss_tag table
                 'do_transactions' => $self->o('do_transactions'),
             },
            -hive_capacity => 500,  
	     -rc_name => 'higerp',
         },

 	 {  -logic_name => 'update_max_alignment_length',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	    -parameters => { 
			    'method_link_species_set_id' => $self->o('mlss_id'),

			   },
	    -flow_into => { 
			    '1->A' => [ 'conservation_scores_healthcheck', 'conservation_jobs_healthcheck' ],
			    'A->1' => ['stats_factory'],
			   },

	    -rc_name => '100Mb',
	 },

# ---------------------------------------------[healthcheck]---------------------------------------------------------------------

        {   -logic_name    => 'conservation_scores_healthcheck',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
             -parameters    => {
                                'test' => 'conservation_scores',
                                'method_link_species_set_id' => $self->o('cs_mlss_id'),
             },
	    -rc_name => '100Mb',
	},

        {   -logic_name    => 'conservation_jobs_healthcheck',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
             -parameters    => {
                                'test' => 'conservation_jobs',
                                'logic_name' => 'Gerp',
                                'method_link_type' => 'PECAN',
             },
	    -rc_name => '100Mb',
 	},

        {   -logic_name => 'stats_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                'fan_branch_code'       => 2,
            },
            -flow_into  => {
                2 => [ 'multiplealigner_stats' ],
            },
        },

        { -logic_name => 'multiplealigner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
	      -parameters => {
			      'skip' => $self->o('skip_multiplealigner_stats'),
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'ensembl_release' => $self->o('release'),
			      'output_dir' => $self->o('output_dir'),
                              'mlss_id'   => $self->o('mlss_id'),
			     },
	      -rc_name => '3.6Gb',             
              -hive_capacity => 100,  
	    },

    ];

}

1;

