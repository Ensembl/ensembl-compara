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

## Configuration file for the Epo Low Coverage pipeline

package Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        'pipeline_name' => $self->o('species_set_name').'_epo_low_coverage_'.$self->o('rel_with_suffix'),

	'populate_new_database_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",

	'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment
	'high_epo_mlss_id' => $self->o('high_epo_mlss_id'), #mlss_id for high coverage epo alignment

	'max_block_size'  => 1000000,                       #max size of alignment before splitting 

	 #gerp parameters
	'gerp_version' => '2.1',                            #gerp program version
	'gerp_window_sizes'    => [1,10,100,500],         #gerp window sizes
	'no_gerp_conservation_scores' => 0,                 #Not used in productions but is a valid argument
        'species_to_skip' => undef,

	#Location of executables (or paths to executables)
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
       'aligner_capacity' => 2000,

       # stats report email
       'epo_stats_report_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/production/epo_stats.pl",
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
       'mkdir -p '.$self->o('output_dir'), #Make output_dir directory
       'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
	   ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
            'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'mlss_id' => $self->o('low_epo_mlss_id'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [

# ---------------------------------------------[find out the other mlss_ids involved ]---------------------------------------------------
#
            {   -logic_name => 'find_gerp_mlss_ids',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                    'db_conn'       => $self->o('master_db'),
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
				  'program'        => $self->o('populate_new_database_program'),
				  'cmd'            => ['#program#', '--master', $self->o('master_db'), '--new', $self->pipeline_url(), '--mlss', '#mlss_id#', '--mlss', '#ce_mlss_id#', '--mlss', '#cs_mlss_id#'],
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
                              'sql' => [
                                  'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#cs_mlss_id#, "msa_mlss_id", ' . $self->o('low_epo_mlss_id') . ')',
                                  'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#ce_mlss_id#, "msa_mlss_id", ' . $self->o('low_epo_mlss_id') . ')',
                                  'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (' . $self->o('low_epo_mlss_id') . ', "high_coverage_mlss_id", ' . $self->o('high_epo_mlss_id') . ')',
                                  'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (' . $self->o('low_epo_mlss_id') . ', "reference_species", "' . $self->o('ref_species') . '")'
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
				'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),
				'sql'   => [
					    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr((#low_epo_mlss_id# * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr((#low_epo_mlss_id# * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr((#low_epo_mlss_id# * 10**10) + 1)expr#',
					   ],
			       },
		-flow_into => {
			       1 => [ 'load_genomedb_factory' ],
			      },
		-rc_name => '100Mb',
	    },

# ---------------------------------------------[Load GenomeDB entries from master+cores]--------------------------------------------------
	    {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
		-parameters => {
				'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
                                'extra_parameters'      => [ 'locator' ],
			       },
		-flow_into => {
                               '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
			       'A->1' => [ 'make_species_tree' ],    # backbone
			      },
		-rc_name => '100Mb',
	    },
	    {   -logic_name => 'load_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-parameters => {
			'master_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
			'registry_dbs'  => [ $self->o('staging_loc1')], #, $self->o('livemirror_loc')],
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
		-rc_name => '100Mb',
	    },

# -------------------------------------------------------------[Load species tree]--------------------------------------------------------
	    {   -logic_name    => 'make_species_tree',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
		-parameters    => { 
                                   'species_tree_input_file' => $self->o('species_tree_file'),
				  },
		-rc_name => '100Mb',
		-flow_into => [ 'create_default_pairwise_mlss'],
	    },

# -----------------------------------[Create a list of pairwise mlss found in the default compara database]-------------------------------
	    {   -logic_name => 'create_default_pairwise_mlss',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::CreateDefaultPairwiseMlss',
		-parameters => {
				'new_method_link_species_set_id' => $self->o('low_epo_mlss_id'),
				'base_method_link_species_set_id' => $self->o('high_epo_mlss_id'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
				'base_location' => $self->o('epo_db'),
				'reference_species' => $self->o('ref_species'),
			       },
		-flow_into => {
			       1 => [ 'import_alignment' ],
			       2 => [ '?table_name=pipeline_wide_parameters' ],
			      },
		-rc_name => '100Mb',
	    },

# ------------------------------------------------[Import the high coverage alignments]---------------------------------------------------
	    {   -logic_name => 'import_alignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment',
		-parameters => {
				'method_link_species_set_id'       => $self->o('high_epo_mlss_id'),
				'from_db_url'                      => $self->o('epo_db'),
			       },
		-flow_into => {
			       1 => [ 'create_low_coverage_genome_jobs' ],
			      },
		-rc_name =>'1Gb',
	    },

# ------------------------------------------------------[Low coverage alignment]----------------------------------------------------------
	    {   -logic_name => 'create_low_coverage_genome_jobs',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery' => 'SELECT genomic_align_block_id FROM genomic_align ga LEFT JOIN dnafrag USING (dnafrag_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id') . ' AND coord_system_name != "ancestralsegment" GROUP BY genomic_align_block_id',
			       },
		-flow_into => {
			       '2->A' => [ 'low_coverage_genome_alignment' ],
			       'A->1' => [ 'delete_alignment' ],
			      },
		-rc_name => '3.5Gb',
	    },
	    {   -logic_name => 'low_coverage_genome_alignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'reference_species' => $self->o('ref_species'),
#				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
                                'semphy_exe' => $self->o('semphy_exe'),
                                'treebest_exe' => $self->o('treebest_exe'),
			       },
		-batch_size     => 10,
		-hive_capacity  => 100,
		#Need a mode to say, do not die immediately if fail due to memory because of memory leaks, rerunning is the solution. Flow to module _again.
		-flow_into => {
			       2 => [ 'gerp' ],
			       -1 => [ 'low_coverage_genome_alignment_again' ],
			      },
		-rc_name => '1.8Gb',
	    },
	    #If fail due to MEMLIMIT, probably due to memory leak, and rerunning with extra memory.
	    {   -logic_name => 'low_coverage_genome_alignment_again',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'reference_species' => $self->o('ref_species'),
#				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
                                'semphy_exe' => $self->o('semphy_exe'),
                                'treebest_exe' => $self->o('treebest_exe'),
			       },
		-batch_size     => 10,
		-hive_capacity  => 100,
        -priority       => 15,
		-flow_into => {
			       2 => [ 'gerp' ],
			       -1 => [ 'low_coverage_genome_alignment_himem' ],
			      },
		-rc_name => '3.5Gb',
	    },

        #Super MEM analysis, there is a small amount of jobs still failing with current RAM limits
        {   -logic_name => 'low_coverage_genome_alignment_himem',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'reference_species' => $self->o('ref_species'),
#				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
                                'semphy_exe' => $self->o('semphy_exe'),
                                'treebest_exe' => $self->o('treebest_exe'),
			       },
		-batch_size     => 10,
		-hive_capacity  => 100,
        -priority       => 20,
		-flow_into => {
			       2 => [ 'gerp' ],
			      },
		-rc_name => '8Gb',
	    },
# ---------------------------------------------------------------[Gerp]-------------------------------------------------------------------
	    {   -logic_name => 'gerp',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
		-parameters => {
				'program_version' => $self->o('gerp_version'),
				'window_sizes' => $self->o('gerp_window_sizes'),
				'gerp_exe_dir' => $self->o('gerp_exe_dir'),
			       },
		-analysis_capacity  => 700,
		-rc_name => '1.8Gb',
	    },

# ---------------------------------------------------[Delete high coverage alignment]-----------------------------------------------------
	    {   -logic_name => 'delete_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'sql' => [
					  'DELETE gat, ga FROM genomic_align_tree gat JOIN genomic_align ga USING (node_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					  'DELETE FROM genomic_align_block WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					 ],
			       },
		-flow_into => {
			       1 => [ 'update_max_alignment_length' ],
			      },
		-rc_name => '1.8Gb',
	    },

# ---------------------------------------------------[Update the max_align data in meta]--------------------------------------------------
	    {  -logic_name => 'update_max_alignment_length',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	        -parameters => {
			       'method_link_species_set_id' => $self->o('low_epo_mlss_id'),
			      },
	       -flow_into => {
			      1 => [ 'create_neighbour_nodes_jobs_alignment' ],
			     },
		-rc_name => '1.8Gb',
	    },

# --------------------------------------[Populate the left and right node_id of the genomic_align_tree table]-----------------------------
	    {   -logic_name => 'create_neighbour_nodes_jobs_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery' => 'SELECT root_id FROM genomic_align_tree WHERE parent_id IS NULL',
			       },
		-flow_into => {
			       '2->A' => [ 'set_neighbour_nodes' ],
			       'A->1' => [ 'healthcheck_factory' ],
			      },
		-rc_name => '1.8Gb',
	    },
	    {   -logic_name => 'set_neighbour_nodes',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-batch_size    => 10,
		-hive_capacity => 20,
		-rc_name => '1.8Gb',
		-flow_into => {
			       -1 => [ 'set_neighbour_nodes_himem' ],
			      },
	    },

	    {   -logic_name => 'set_neighbour_nodes_himem',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-batch_size    => 5,
		-hive_capacity => 20,
		-rc_name => '3.5Gb',
	    },
# -----------------------------------------------------------[Run healthcheck]------------------------------------------------------------
            {   -logic_name => 'healthcheck_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -meadow_type=> 'LOCAL',
                -flow_into => {
                               '2->A' => {
                                     'conservation_score_healthcheck'  => [
                                                                           {'test' => 'conservation_jobs', 'logic_name'=>'gerp','method_link_type'=>'EPO_LOW_COVERAGE'}, 
                                                                           {'test' => 'conservation_scores','method_link_species_set_id'=>'#cs_mlss_id#'},
                                                                ],
                                    },
                               'A->1' => ['register_mlss'],
                              },
            },

	    {   -logic_name => 'conservation_score_healthcheck',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
		-rc_name => '100Mb',
	    },

        {   -logic_name => 'register_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::RegisterMLSS',
            -parameters => {
                'master_db'     => $self->o('master_db'),
            },
            -flow_into  => [ 'multiplealigner_stats_factory' ],
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats::pipeline_analyses_multiple_aligner_stats($self) },

     ];
}
1;
