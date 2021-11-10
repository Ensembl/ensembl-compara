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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -species_set_name <species_set_name> -reuse_db <db_alias_or_url>

=head1 DESCRIPTION

    The PipeConfig file for MercatorPecan pipeline that should automate most of the pre-execution tasks.

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
	'do_not_reuse_list'     => [ ],     # genome_db_ids of species we don't want to reuse this time. This is normally done automatically, so only need to set this if we think that this will not be picked up automatically.
	#'species_set_name'      => 'amniotes',

    # Automatically set using the above
        'pipeline_name'         => $self->o('species_set_name').'_mercator_pecan_'.$self->o('rel_with_suffix'),
        'method_type'           => 'PECAN',

    # dependent parameters:
        'work_dir'              => $self->o('pipeline_dir'),
        'blastdb_dir'           => $self->o('work_dir') . '/blast_db',  
        'mercator_dir'          => $self->o('work_dir') . '/mercator',  

        # Master database
        'master_db' => 'compara_master',
        # Previous release data location for reuse
        # 'reuse_db'  => 'amniotes_pecan_prev',

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
    'java_options'      => '-server -Xmx1300M',
    'java_options_mem1' => '-server -Xmx6500M -Xms6000m',
    'java_options_mem2' => '-server -Xmx12500M -Xms12000m',
    'java_options_mem3' => '-server -Xmx26500M -Xms26000m',
    'java_options_mem4' => '-server -Xmx76500M -Xms76000m',

    #Gerp default parameters
    'window_sizes'      => [1,10,100,500],

    #Default statistics
    'skip_multiplealigner_stats' => 0, #skip this module if set to 1
    'bed_dir' => $self->o('work_dir') . '/bed_dir/',
    'output_dir' => $self->o('work_dir') . '/feature_dumps/',

     #Resource requirements
    'pecan_capacity'        => 500,
    'pecan_himem_capacity'  => 1000,
    'gerp_capacity'         => 500,
    'blast_capacity'        => 100,
    'reuse_capacity'        => 5,
    };
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'genome_dumps_dir' => $self->o('genome_dumps_dir'),
        'work_dir'         => $self->o('work_dir'),
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        $self->pipeline_create_commands_rm_mkdir(['blastdb_dir', 'mercator_dir', 'output_dir', 'bed_dir']),
     ];
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
# ---------------------------------------------[find out the mlss_ids involved ]---------------------------------------------------
#
        {   -logic_name => 'load_mlss_ids',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -parameters => {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('species_set_name'),
                'release'          => $self->o('ensembl_release'),
                'add_sister_mlsss' => 1,  # Load GERP MLSS ids as well
                'master_db'        => $self->o('master_db'),
            },
            -input_ids  => [{}],
            -flow_into  => [ 'populate_new_database' ],
            -rc_name    => '500Mb_job',
        },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'  => $self->o('populate_new_database_exe'),
                  'reg_conf' => $self->o('reg_conf'),
				  'cmd'      => "#program# --master " . $self->o('master_db') . " --new " . $self->pipeline_url() . " --mlss #mlss_id# --mlss #ce_mlss_id# --mlss #cs_mlss_id# --reg-conf #reg_conf#",
				 },
	       -flow_into => {
			      1 => [ 'set_mlss_tag' ],
			     },
		-rc_name => '1Gb_job',
	    },

# -------------------------------------------[Set conservation score method_link_species_set_tag ]------------------------------------------
            { -logic_name => 'set_mlss_tag',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
              -parameters => {
                  'sql' => [ 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#cs_mlss_id#, "msa_mlss_id", #mlss_id#)',
                             'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#ce_mlss_id#, "msa_mlss_id", #mlss_id#)',
                           ],
                             },
              -flow_into => {
                             1 => [ 'set_internal_ids' ],
                            },
            },

# ------------------------------------------------------[Set internal ids ]---------------------------------------------------------------
	    {   -logic_name => 'set_internal_ids',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'sql'   => [
					    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
                                            # CreateReuseSpeciesSets/PrepareSpeciesSetsMLSS may want to create new
                                            # entries. We need to make sure they don't collide with the master database
                                            'ALTER TABLE species_set_header      AUTO_INCREMENT=10000001',
                                            'ALTER TABLE method_link_species_set AUTO_INCREMENT=10000001',
					   ],
			       },
		-flow_into => {
                               1 => [ 'load_genomedb_factory' ],
			      },
	    },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'compara_db'       => $self->o('master_db'),   # that's where genome_db_ids come from
                'master_db'        => $self->o('master_db'),
                'extra_parameters' => [ 'locator' ],
            },
            -flow_into  => {
                '2->A'  => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
                'A->1'  => [ 'create_mlss_ss' ],
            },
            -rc_name    => '500Mb_job',
	},

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'db_version' => $self->o('ensembl_release'),
                'master_db'  => $self->o('master_db'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'check_reusability' ],   # each will flow into another one
            },
        },

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckMembersReusability',
            -parameters => {
		        'reuse_db'          => $self->o('reuse_db'),
		        'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                2 => [ 'check_reuse_db', '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id' ],
                3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
            },
	    -rc_name => '2Gb_job',
        },

	{   -logic_name => 'check_reuse_db',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::CheckReuseDB',
	    -parameters => {
		      'reuse_db' => $self->o('reuse_db'),
	    },
	    -rc_name => '2Gb_job',
        },

        {   -logic_name => 'create_mlss_ss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
            -parameters => {
                'master_db'          => $self->o('master_db'),
                'whole_method_links' => [ $self->o('method_type') ],
            },
            -flow_into  => [ 'make_species_tree' ],
            -rc_name    => '500Mb_job',
        },

        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => { 
                               'species_tree_input_file' => $self->o('binary_species_tree'),
                              },
            -flow_into => {
                           1 => [ 'set_gerp_neutral_rate' ],
                          },
        },

        {   -logic_name => 'set_gerp_neutral_rate',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetGerpNeutralRate',
            -flow_into => {
                1 => [ 'genome_reuse_factory' ],
            },
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
                            'ALTER TABLE peptide_align_feature_#genome_db_id# ADD KEY hgenome_rank_hmember (hgenome_db_id, hit_rank, hmember_id)',
               ],
            },
            -flow_into => {
                 1 => [ 'load_fresh_members' ],
            },
        },

        {   -logic_name => 'load_fresh_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => {'coding_exons' => 1,
			    'min_length' => 20,
                },
	    -rc_name => '4Gb_job',
        },


# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'blastdb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -flow_into  => {
                '2->A'  => [ 'delete_non_nuclear_genes' ],
                'A->1'  => [ 'blast_species_factory' ],
            },
        },

        {   -logic_name => 'delete_non_nuclear_genes',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => 'DELETE seq_member FROM seq_member JOIN dnafrag USING (dnafrag_id) WHERE cellular_component != "NUC" AND seq_member.genome_db_id = #genome_db_id#',
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
	    -rc_name => '2Gb_job',
        },

        {   -logic_name => 'make_blastdb',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'fasta_dir'     => $self->o('blastdb_dir'),
                'blast_bin_dir' => $self->o('blast_bin_dir'),
                'cmd'           => '#blast_bin_dir#/makeblastdb -dbtype prot -parse_seqids -logfile #fasta_dir#/make_blastdb.log -in #fasta_name#',
            },
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
	    -rc_name => '1Gb_job',
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
	    -rc_name => '2Gb_job',
        },


# ---------------------------------------------[mercator]---------------------------------------------------------------

         {   -logic_name => 'mercator_file_factory',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory',
	    -flow_into => { 
			    'A->1' => { 'mercator' => undef },
			    '2->A' => ['dump_mercator_files'],
			   },
         },

         {   -logic_name => 'dump_mercator_files',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpMercatorFiles',
             -parameters => { 'maximum_gap' => $self->o('maximum_gap'),
			      'input_dir'   => $self->o('input_dir'),
			      'all_hits'    => $self->o('all_hits'),
			    },
	     -rc_name => '2Gb_job',
             -analysis_capacity => 8,
         },

         {   -logic_name => 'mercator',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Mercator',
             -parameters => {
			     'input_dir' => $self->o('input_dir'),
                             'mercator_exe' => $self->o('mercator_exe'),
			    },
	     -rc_name => '32Gb_job',
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
		-1 => [ 'pecan_mem1'],
		-2 => [ 'pecan_mem1'], #RUNLIMIT
             },
	    -rc_name => '2Gb_job',
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
             -priority => 15,
	     -rc_name => '8Gb_job',
             -hive_capacity => $self->o('pecan_himem_capacity'),
             -flow_into => {
                 1 => [ 'gerp' ],
		-1 => [ 'pecan_mem2'],
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
             -priority => 20,
	     -rc_name => '16Gb_job',
             -hive_capacity => $self->o('pecan_himem_capacity'),
             -flow_into => {
                 1 => [ 'gerp' ],
		-1 => [ 'pecan_mem3'],
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
             -priority => 40,
	     -rc_name => '32Gb_job',
             -flow_into => {
                 1 => [ 'gerp' ],
                 -1 => [ 'pecan_mem4'],
                 -2 => [ 'pecan_mem4'], #RUNLIMIT
             },
         },
         {   -logic_name => 'pecan_mem4',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
             -parameters => {
                 'max_block_size'             => $self->o('max_block_size'),
                 'java_options'               => $self->o('java_options_mem4'),
                 'pecan_exe_dir'              => $self->o('pecan_exe_dir'),
                 'exonerate_exe'              => $self->o('exonerate_exe'),
                 'java_exe'                   => $self->o('java_exe'),
                 'estimate_tree_exe'          => $self->o('estimate_tree_exe'),
                 'ortheus_bin_dir'            => $self->o('ortheus_bin_dir'),
                 'ortheus_lib_dir'            => $self->o('ortheus_lib_dir'),
                 'semphy_exe'                 => $self->o('semphy_exe'),
             },
             -max_retry_count => 1,
             -priority => 50,
             -rc_name => '96Gb_job',
             -flow_into => {
                 1 => [ 'gerp' ],
             },
         },
# ---------------------------------------------[gerp]---------------------------------------------------------------------

         {   -logic_name    => 'gerp',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
             -parameters    => {
                 'window_sizes'    => $self->o('window_sizes'),
		 'gerp_exe_dir'    => $self->o('gerp_exe_dir'),
#                 'constrained_element_method_link_type' => $self->o('constrained_element_type'),
             },
             -hive_capacity => $self->o('gerp_capacity'),
             -flow_into => {
		 -1 => [ 'gerp_himem'], #retry with more memory
             },
	     -rc_name => '1Gb_job',
         },
         {   -logic_name    => 'gerp_himem',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
             -parameters    => {
                 'window_sizes'    => $self->o('window_sizes'),
		 'gerp_exe_dir'    => $self->o('gerp_exe_dir'),
             },
            -hive_capacity => $self->o('gerp_capacity'),
	     -rc_name => '4Gb_job',
         },

 	 {  -logic_name => 'update_max_alignment_length',
	    -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	    -parameters => { 
			    'method_link_species_set_id' => '#mlss_id#',

			   },
	    -flow_into => { 
			    '1->A' => [ 'conservation_scores_healthcheck', 'conservation_jobs_healthcheck' ],
			    'A->1' => WHEN( 'not #skip_multiplealigner_stats#' => [ 'multiplealigner_stats_factory' ] ),
			   },

	 },

# ---------------------------------------------[healthcheck]---------------------------------------------------------------------

        {   -logic_name    => 'conservation_scores_healthcheck',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
             -parameters    => {
                                'test' => 'conservation_scores',
                                'method_link_species_set_id' => '#cs_mlss_id#',
             },
	},

        {   -logic_name    => 'conservation_jobs_healthcheck',
             -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
             -parameters    => {
                                'test' => 'conservation_jobs',
                                'logic_name' => 'Gerp',
                                'method_link_type' => $self->o('method_type'),
             },
 	},

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats::pipeline_analyses_multiple_aligner_stats($self) },

    ];

}

1;
