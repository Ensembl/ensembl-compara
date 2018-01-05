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

Bio::EnsEMBL::Compara::PipeConfig::Legacy::ImportUcscChainNet_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Download the chain and net files from UCSC
        a) Goto the downloads directory:
          http://hgdownload.cse.ucsc.edu/downloads.html
        b) Select the reference species eg human
        c) Get the chain and net files by selecting the relevant Pairwise Alignments 
        Eg To import the human-human self alignments:
        wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/hg19.hg19.all.chain.gz
        wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/hg19.hg19.net.gz
        d) Get the chromInfo file and the mapping file (if necessary):
          Eg human: Select "Annotation database" from the Human Genome page (step (b) above)
          wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/database/chromInfo.txt.gz
          wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/database/ctgPos.txt.gz

    #4. Make sure that all default_options are set correctly, especially:
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        
    #5. Run init_pipeline.pl script: eg for human self alignments
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Legacy::ImportUcscChainNet_conf --dbname hsap_hsap_ucsc_test --password <your_password) -mlss_id 1 --ref_species homo_sapiens --non_ref_species homo_sapiens --chain_file hg19.hg19.all.chain --net_file hg19.hg19.net --ref_chromInfo_file hsap/chromInfo.txt --ref_ucsc_map ctgPos.txt --ucsc_url http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

This pipeline populates a compara database using the Chain (--chain_file) and Net files (--net_file) produced by UCSC. It uses the chromInfo file (--ref_chromInfo_file, --non_ref_chromInfo_file) to convert between UCSC and Ensembl chromosome names. It may additionally need a mapping file (--ref_ucsc_map, --non_ref_ucsc_map), such as ctgPos.txt to convert the supercontig names for human.
It is recommended that you provide a meaningful database name (--dbname). The username is automatically prefixed to this, ie -dbname hsap_hsap_lastz_65 will become kb3_hsap_hsap_lastz_65. The URL of the downloads is defined using --ucsc_url.


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Legacy::ImportUcscChainNet_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	'pipeline_name'         => 'ucsc_import_'.$self->o('rel_with_suffix'),

	master_db => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'mm14_ensembl_compara_master',
	    -driver => 'mysql',
       },
	'staging_loc1' => {
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },
        'staging_loc2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },  
	 'livemirror_loc' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => 69,
        },

	#'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
	'curr_core_sources_locs'    => [ $self->o('livemirror_loc'), ],

	# executable locations:
	'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",
	'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
	'update_config_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/update_config_database.pl",
	'create_pair_aligner_page_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl",
        'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

	#Set for single pairwise mode
	'mlss_id' => '',

	#Set to use registry configuration file
	'reg_conf' => '',

	#Reference species (if not using pairwise configuration file)
	'ref_species' => 'homo_sapiens',

         'skip_pairaligner_stats' => 0, #skip this module if set to 1

	'chain_method_link_type' => 'LASTZ_CHAIN',
	'net_method_link_type' => 'LASTZ_NET',

        'ref_ucsc_map' => '',
        'non_ref_ucsc_map' => '',

	'non_ref_chromInfo_file' => '', #not defined for self alignments

	#
	#Default healthcheck
	#
	'previous_db' => $self->o('livemirror_loc'),
	'prev_release' => 0,   # 0 is the default and it means "take current release number and subtract 1"    
	'max_percent_diff' => 20,

        #
	#Default pairaligner config
	#
	'bed_dir' => '/nfs/ensembl/compara/dumps/bed/',
	#'config_url' => '', #Location of pairwise config database. Must define on command line
	#'ucsc_url' => '', #Location of ucsc url. Must define on command line
	'output_dir' => '/lustre/scratch103/ensembl/' . $ENV{USER} . '/pair_aligner/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
       'mkdir -p '.$self->o('output_dir'), #Make output_dir directory
       $self->db_cmd('CREATE TABLE ucsc_to_ensembl_mapping (genome_db_id int(10) unsigned, ucsc varchar(40),ensembl  varchar(40)) ENGINE=InnoDB'),

    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
         '100Mb' => { 'LSF' => '-C0 -M100000 -R"select[mem>100] rusage[mem=100]"' },
         '1Gb'   => { 'LSF' => '-C0 -M1000000 -R"select[mem>1000] rusage[mem=1000]"' },
         '1.8Gb' => { 'LSF' => '-C0 -M1800000 -R"select[mem>1800] rusage[mem=1800]"' },
         '3.6Gb' => { 'LSF' => '-C0 -M3600000 -R"select[mem>3600] rusage[mem=3600]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    print "pipeline_analyses\n";

    return [

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'mlss_id'        => $self->o('mlss_id'),
				  'speciesList'    => "",
				  'reg_conf'        => $self->o('reg_conf'),
				  'cmd'            => "#program# --master " . $self->dbconn_2_url('master_db') . " --new " . $self->pipeline_url() . " --mlss #mlss_id# ",
				 },
	       -flow_into => {
			      1 => [ 'load_genomedb_factory' ],
			     },
	       -input_ids => [{}],
               -rc_name => '1Gb',
	    },
	    {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
		-parameters => {
				'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
				'mlss_id'       => $self->o('mlss_id'),
                                'extra_parameters'      => [ 'locator' ],
			       },
		-flow_into => {
                               '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
			       'A->1' => [ 'load_genomedb_funnel' ],    # backbone
			      },
                -rc_name => '100Mb',
	    },

	    {   -logic_name => 'load_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-parameters => {
				'registry_dbs'  => $self->o('curr_core_sources_locs'),
                                'db_version'    => $self->o('ensembl_release'),
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
                -rc_name => '100Mb',
	    },
	    {   -logic_name => 'load_genomedb_funnel',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputlist' => [
						[ 
						 $self->o('ref_species'),
						  $self->o('ref_chromInfo_file'),
						  $self->o('ref_ucsc_map'),
						],
						[
						 $self->o('non_ref_species'),
						  $self->o('non_ref_chromInfo_file'),
						  $self->o('non_ref_ucsc_map'),
						],
				],
				'column_names' => [ 'species', 'chromInfo_file', 'ucsc_map'],
		},
		-flow_into => {
			       '2->A' => [ 'ucsc_to_ensembl_mapping' ],
			       'A->1' => [ 'chain_factory' ],
		},
                -rc_name => '100Mb',
	    },

	    {  -logic_name => 'ucsc_to_ensembl_mapping',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscToEnsemblMapping',
               -rc_name => '100Mb',
	    },

	    {   -logic_name => 'chain_factory',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscChainFactory',
		-parameters => {
				'step' => 200000,
				'chain_file'  => $self->o('chain_file'),
			       },
		-flow_into => {
			       '2->A' => [ 'import_chains' ],
			       'A->1' => [ 'set_internal_ids' ],
			      },
                -rc_name => '100Mb',
	    },
	    
 	    {  -logic_name => 'import_chains',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportChains',
 	       -parameters => {
			       'chain_file'  => $self->o('chain_file'),
			       'ref_species' => $self->o('ref_species'),
			       'non_ref_species' => $self->o('non_ref_species'),
			       'output_method_link_type' => $self->o('chain_method_link_type'),
			      },
 	       -hive_capacity => 20,
               -rc_name => '1.8Gb',
 	    },
	    
	    {  -logic_name => 'net_factory',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
	       -parameters => {
			       'inputquery'    => "SELECT dnafrag_id FROM dnafrag join genome_db using (genome_db_id) WHERE genome_db.name='".$self->o('ref_species')."'",
			       },
		-flow_into => {
			       '2->A' => [ 'import_nets'  ],
			       'A->1' => [ 'update_max_alignment_length_after_net' ],
			      },
               -rc_name => '100Mb',
	    },
	    {  -logic_name => 'set_internal_ids',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIds',
 	       -parameters => {
			       'tables' => [ 'genomic_align_block', 'genomic_align' ],
			       'method_link_species_set_id' => $self->o('mlss_id'),
			      },
               -rc_name => '100Mb',
               -flow_into  => [ 'net_factory' ],
 	    },
 	    {  -logic_name => 'import_nets',
 	       -hive_capacity => 20,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportNets',
 	       -parameters => {
			       'net_file'  => $self->o('net_file'),
			       'output_mlss_id' => $self->o('mlss_id'),
			       'ref_species' => $self->o('ref_species'),
			       'non_ref_species' => $self->o('non_ref_species'),
			       'input_method_link_type' => $self->o('chain_method_link_type'),
			       'output_method_link_type' => $self->o('net_method_link_type'),
			      },
	       -flow_into => {
			      -1 => [ 'import_nets_himem' ],
			     },
	       -rc_name => '1.8Gb',
 	    },
 	    {  -logic_name => 'import_nets_himem',
 	       -hive_capacity => 20,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportNets',
 	       -parameters => {
			       'net_file'  => $self->o('net_file'),
			       'output_mlss_id' => $self->o('mlss_id'),
			       'ref_species' => $self->o('ref_species'),
			       'non_ref_species' => $self->o('non_ref_species'),
			       'input_method_link_type' => $self->o('chain_method_link_type'),
			       'output_method_link_type' => $self->o('net_method_link_type'),
			      },
               -rc_name => '3.6Gb',
 	    },
  	    {  -logic_name => 'update_max_alignment_length_after_net',
  	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
  	       -parameters => { 
			       'method_link_species_set_id' => $self->o('mlss_id'),
 			      },
		-flow_into => {
			       1 => { 'healthcheck' => [
							{ 'test' => 'pairwise_gabs', 'mlss_id' => $self->o('mlss_id') },
							{ 'test' => 'compare_to_previous_db', 'mlss_id' => $self->o('mlss_id')},
						      ],
				    },
			      },
               -rc_name => '100Mb',
  	    },
 	    { -logic_name => 'healthcheck',
 	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
 	      -parameters => {
 			      'previous_db' => $self->o('previous_db'),
 			      'ensembl_release' => $self->o('ensembl_release'),
 			      'prev_release' => $self->o('prev_release'),
 			      'max_percent_diff' => $self->o('max_percent_diff'),
 			     },
	      -flow_into => {
			     1 => { 'pairaligner_stats' => [{'mlss_id' => $self->o('mlss_id'),'ref_species' => $self->o('ref_species')}
							     ],
				  },
			    },
              -rc_name => '100Mb',
 	    },
            { -logic_name => 'pairaligner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
	      -parameters => {
			      'skip' => $self->o('skip_pairaligner_stats'),
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'create_pair_aligner_page' => $self->o('create_pair_aligner_page_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'ensembl_release' => $self->o('ensembl_release'),
			      'reg_conf' => $self->o('reg_conf'),
			      'output_dir' => $self->o('output_dir'),
                              'ucsc_url' => $self->o('ucsc_url'),
			     },
	      -rc_name => '1Gb',
	    },

	   ];
}

1;
