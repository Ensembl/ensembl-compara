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

Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf -password <your_password> -mlss_id <your_current_Pecan_mlss_id>

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

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones


    # parameters that are likely to change from execution to another:
	#pecan mlss_id
#       'mlss_id'               => 522,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        #'species_set'           => '24amniotes',
	'do_not_reuse_list'     => [ ],     # genome_db_ids of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.
#	'do_not_reuse_list'     => [ 142 ],     # names of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.
	#'species_set_name'      => 'amniotes',

    # Automatically set using the above
        'pipeline_name'         => $self->o('species_set_name').'_mercator_pecan_'.$self->o('rel_with_suffix'),

    # dependent parameters:
        'blastdb_dir'           => $self->o('work_dir') . '/blast_db',  
        'mercator_dir'          => $self->o('work_dir') . '/mercator',  

    # blast parameters:
	'blast_params'          => "-seg 'yes' -best_hit_overhang 0.2 -best_hit_score_edge 0.1 -use_sw_tback",

    # Mercator default parameters
    'strict_map'        => 1,
#    'cutoff_score'     => 100,   #not normally defined
#    'cutoff_evalue'    => 1e-5, #not normally defined
    'maximum_gap'       => 50000,
    'input_dir'         => $self->o('work_dir').'/mercator',
    'all_hits'          => 0,

    #Pecan default parameters
    'max_block_size'    => 1000000,
    'java_options'      => '-server -Xmx1000M',
    'java_options_mem1' => '-server -Xmx3500M -Xms3000m',
    'java_options_mem2' => '-server -Xmx6500M -Xms6000m',
    'java_options_mem3' => '-server -Xmx21500M -Xms21000m',

    #Gerp default parameters
    'window_sizes'      => [1,10,100,500],
	    
    #Location of compara scripts
    'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl", 
    'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
    'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

    #
    #Default statistics
    #
    'skip_multiplealigner_stats' => 0, #skip this module if set to 1
    'bed_dir' => $self->o('work_dir') . '/bed_dir/',
    'output_dir' => $self->o('work_dir') . '/feature_dumps/',


     #
     #Resource requirements
     #
     'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
    'pecan_capacity'        => 500,
    'pecan_himem_capacity'  => 1000,
    'gerp_capacity'         => 500,
    'blast_capacity'        => 100,
    'reuse_capacity'        => 5,

     # stats report email
     'epo_stats_report_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/production/epo_stats.pl",
    };
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
        'mlss_id'        => $self->o('mlss_id'),
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('blastdb_dir'),
        'mkdir -p '.$self->o('mercator_dir'),
        'which lfs && lfs getstripe '.$self->o('blastdb_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('blastdb_dir').' -c -1 || echo "Striping is not available on this system" ',
        'mkdir -p '.$self->o('output_dir'), #Make output_dir directory
        'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
     ];
}

# Syntax for LSF farm 3
#sub resource_classes {
#    my ($self) = @_;
#    return {
#         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
#         '100Mb' =>  { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
#         '1Gb' =>    { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
#         '1.8Gb' =>  { 'LSF' => '-C0 -M1800 -R"select[mem>1800 && '. $self->o('dbresource'). '<'.$self->o('aligner_capacity').'] rusage[mem=1800,'.$self->o('dbresource').'=10:duration=11]"' },
#         '3.5Gb' =>  { 'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
#         '7Gb' =>  { 'LSF' => '-C0 -M7000 -R"select[mem>7000] rusage[mem=7000]"' },
#         '14Gb' => { 'LSF' => '-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"' },
#         '30Gb' =>   { 'LSF' => '-C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"' },
#         'gerp' =>   { 'LSF' => '-C0 -M1000 -R"select[mem>1000 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1000,'.$self->o('dbresource').'=10:duration=11]"' },
#         'higerp' =>   { 'LSF' => '-C0 -M3800 -R"select[mem>3800 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=3800,'.$self->o('dbresource').'=10:duration=11]"' },
#    };
#}

sub pipeline_analyses {
    my ($self) = @_;

    return [
# ---------------------------------------------[find out the other mlss_ids involved ]---------------------------------------------------
#
            {   -logic_name => 'find_gerp_mlss_ids',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                    'db_conn'       => $self->o('master_db'),
                    'mlss_id'       => $self->o('mlss_id'),
                    'ce_ml_type'    => 'GERP_CONSTRAINED_ELEMENT',
                    'cs_ml_type'    => 'GERP_CONSERVATION_SCORE',
                    'inputquery'    => 'SELECT mlss_ce.method_link_species_set_id AS ce_mlss_id, mlss_cs.method_link_species_set_id AS cs_mlss_id FROM method_link_species_set mlss JOIN (method_link_species_set mlss_ce JOIN method_link ml_ce USING (method_link_id)) USING (species_set_id) JOIN (method_link_species_set mlss_cs JOIN method_link ml_cs USING (method_link_id)) USING (species_set_id) WHERE mlss.method_link_species_set_id = #mlss_id# AND ml_ce.type = "#ce_ml_type#" AND ml_cs.type = "#cs_ml_type#"',
                },
                -input_ids => [{}],
                -flow_into => {
                    2 => 'populate_new_database',
                },
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'cmd'            => "#program# --master " . $self->o('master_db') . " --new " . $self->pipeline_url() . " --mlss #mlss_id# --mlss #ce_mlss_id# --mlss #cs_mlss_id# ",
				 },
	       -flow_into => {
			      1 => [ 'set_mlss_tag' ],
			     },
		-rc_name => '1Gb',
	    },

# -------------------------------------------[Set conservation score method_link_species_set_tag ]------------------------------------------
            { -logic_name => 'set_mlss_tag',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
              -parameters => {
                  'sql' => [ 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#cs_mlss_id#, "msa_mlss_id", ' . $self->o('mlss_id') . ')',
                             'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#ce_mlss_id#, "msa_mlss_id", ' . $self->o('mlss_id') . ')',
                           ],
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
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from

                'extra_parameters'      => [ 'locator' ],
            },
            -flow_into => {
                '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
                'A->1' => [ 'create_mlss_ss' ],
            },
	    -rc_name => '100Mb',
	},

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
                'master_db' => $self->o('master_db'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
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
		'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                2 => [ 'check_reuse_db', '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id' ],
                3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
            },
	    -rc_name => '1Gb',
        },

	{   -logic_name => 'check_reuse_db',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::CheckReuseDB',
	    -parameters => {
		'reuse_url'   => $self->dbconn_2_url('reuse_db'),
	    },
	    -rc_name => '1.8Gb',
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'master_db' => $self->o('master_db'),
                'whole_method_links'    => [ 'PECAN' ],
            },
            -flow_into => [ 'make_species_tree' ],
        },

        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => { 
                               'species_tree_input_file' => $self->o('species_tree_file'),
                              },
            -flow_into => {
                           1 => [ 'genome_reuse_factory' ],
                          },
            -rc_name => '100Mb',
        },

# ---------------------------------------------[reuse members and pafs]--------------------------------------------------------------

        {   -logic_name => 'genome_reuse_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'species_set_id'    => '#reuse_ss_id#',
            },
            -flow_into => {
                '2->A' => [ 'sequence_table_reuse' ],
                'A->1' => [ 'genome_loadfresh_factory' ],
            },
        },


        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin',
            -parameters => {
                'db_conn'    => $self->o('reuse_db'),
                'table'      => 'sequence',
                'inputquery' => 'SELECT s.* FROM sequence s JOIN seq_member USING (sequence_id) WHERE genome_db_id = #genome_db_id#',
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => [ 'seq_member_table_reuse' ],    # n_reused_species
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
            -hive_capacity => $self->o('reuse_capacity'),
	    -rc_name => '100Mb',
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'genome_loadfresh_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'species_set_id'    => '#nonreuse_ss_id#',
                'extra_parameters'  => [ 'name' ],
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
			    'min_length' => 20,
                'production_db_url' => $self->o('production_db_url'),
                },
	    -rc_name => '1.8Gb',
        },


# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'blastdb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -rc_name       => '100Mb',
            -flow_into  => {
                '2->A'  => [ 'delete_non_nuclear_genes' ],
                'A->1'  => [ 'blast_species_factory' ],
            },
        },

        {   -logic_name => 'delete_non_nuclear_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => 'DELETE seq_member FROM seq_member JOIN dnafrag USING (dnafrag_id) WHERE cellular_component != "NUC"',
            },
            -flow_into  => [ 'fresh_dump_subset_fasta' ],
        },

        {   -logic_name => 'fresh_dump_subset_fasta',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',
            -parameters => {
                 'fasta_dir'                 => $self->o('blastdb_dir'),
            },
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
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
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
		'fasta_dir'    => $self->o('blastdb_dir'),
            },
            -batch_size => 10,
            -hive_capacity => $self->o('blast_capacity'),
	    -rc_name => '1.8Gb',
        },


# ---------------------------------------------[mercator]---------------------------------------------------------------

         {   -logic_name => 'mercator_file_factory',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory',
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
             -parameters => {
			     'input_dir' => $self->o('input_dir'),
                             'mercator_exe' => $self->o('mercator_exe'),
			    },
	     -rc_name => '14Gb',
             -flow_into => {
                 "2->A" => WHEN (
                    "(#total_residues_count# <= 3000000) || ( #dnafrag_count# <= 10 )"                          => "pecan",
                    "(#total_residues_count# > 3000000) && (#total_residues_count# <= 30000000) && (#dnafrag_count# > 10)&&(#dnafrag_count# <= 25)"  => "pecan_mem1",
                    "(#total_residues_count# > 30000000) && (#total_residues_count# <= 60000000) && (#dnafrag_count# > 10)&&(#dnafrag_count# <= 25)" => "pecan_mem2",
                    "(#total_residues_count# > 3000000) && (#total_residues_count# <= 60000000) && (#dnafrag_count# > 25)"      => "pecan_mem2",
                    "(#total_residues_count# > 60000000) && (#dnafrag_count# > 10)"      => "pecan_mem3",
                    ),

                 "A->1" => [ "update_max_alignment_length" ],
             },
         },

# ---------------------------------------------[pecan]---------------------------------------------------------------------

         {   -logic_name => 'pecan',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options'),
                 'pecan_exe_dir'              => $self->o('pecan_exe_dir'),
                 'exonerate_exe'              => $self->o('exonerate_exe'),
                 'java_exe'                   => $self->o('java_exe'),
                 'estimate_tree_exe'          => $self->o('estimate_tree_exe'),
                 'ortheus_bin_dir'            => $self->o('ortheus_bin_dir'),
                 'ortheus_lib_dir'            => $self->o('ortheus_lib_dir'),
                 'semphy_exe'                 => $self->o('semphy_exe'),
             },
             -max_retry_count => 1,
             -priority => 1,
             -hive_capacity => $self->o('pecan_capacity'),
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
                 'pecan_exe_dir'              => $self->o('pecan_exe_dir'),
                 'exonerate_exe'              => $self->o('exonerate_exe'),
                 'java_exe'                   => $self->o('java_exe'),
                 'estimate_tree_exe'          => $self->o('estimate_tree_exe'),
                 'ortheus_bin_dir'            => $self->o('ortheus_bin_dir'),
                 'ortheus_lib_dir'            => $self->o('ortheus_lib_dir'),
                 'semphy_exe'                 => $self->o('semphy_exe'),
             },
             -max_retry_count => 1,
             -priority => 1,
	     -rc_name => '7Gb',
             -hive_capacity => $self->o('pecan_himem_capacity'),
             -flow_into => {
                 1 => [ 'gerp' ],
		 2 => [ 'pecan_mem2'], #retry with even more heap memory
		-1 => [ 'pecan_mem2'], #MEMLIMIT
		-2 => [ 'pecan_mem2'], #RUNLIMIT
             },
         },
         {   -logic_name => 'pecan_mem2',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options_mem2'),
                 'pecan_exe_dir'              => $self->o('pecan_exe_dir'),
                 'exonerate_exe'              => $self->o('exonerate_exe'),
                 'java_exe'                   => $self->o('java_exe'),
                 'estimate_tree_exe'          => $self->o('estimate_tree_exe'),
                 'ortheus_bin_dir'            => $self->o('ortheus_bin_dir'),
                 'ortheus_lib_dir'            => $self->o('ortheus_lib_dir'),
                 'semphy_exe'                 => $self->o('semphy_exe'),
             },
             -max_retry_count => 1,
             -priority => 1,
	     -rc_name => '14Gb',
             -hive_capacity => $self->o('pecan_himem_capacity'),
             -flow_into => {
                 1 => [ 'gerp' ],
		 2 => [ 'pecan_mem3'], #retry with even more heap memory
		-1 => [ 'pecan_mem3'], #MEMLIMIT
		-2 => [ 'pecan_mem3'], #RUNLIMIT
             },
         },
         {   -logic_name => 'pecan_mem3',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options_mem3'),
                 'pecan_exe_dir'              => $self->o('pecan_exe_dir'),
                 'exonerate_exe'              => $self->o('exonerate_exe'),
                 'java_exe'                   => $self->o('java_exe'),
                 'estimate_tree_exe'          => $self->o('estimate_tree_exe'),
                 'ortheus_bin_dir'            => $self->o('ortheus_bin_dir'),
                 'ortheus_lib_dir'            => $self->o('ortheus_lib_dir'),
                 'semphy_exe'                 => $self->o('semphy_exe'),
             },
             -max_retry_count => 1,
             -priority => 1,
	     -rc_name => '30Gb',
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
#                 'constrained_element_method_link_type' => $self->o('constrained_element_type'),
             },
             -hive_capacity => $self->o('gerp_capacity'),
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
             },
            -hive_capacity => $self->o('gerp_capacity'),
	     -rc_name => 'higerp',
         },

 	 {  -logic_name => 'update_max_alignment_length',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	    -parameters => { 
			    'method_link_species_set_id' => '#mlss_id#',

			   },
	    -flow_into => { 
			    '1->A' => [ 'conservation_scores_healthcheck', 'conservation_jobs_healthcheck' ],
			    'A->1' => ['multiplealigner_stats_factory'],
			   },

	    -rc_name => '100Mb',
	 },

# ---------------------------------------------[healthcheck]---------------------------------------------------------------------

        {   -logic_name    => 'conservation_scores_healthcheck',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
             -parameters    => {
                                'test' => 'conservation_scores',
                                'method_link_species_set_id' => '#cs_mlss_id#',
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

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats::pipeline_analyses_multiple_aligner_stats($self) },

    ];

}

1;

