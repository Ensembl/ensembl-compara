=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

##
## Configuration file for DumpMultiAlign pipeline
#Release 65
#
#epo 6 way
#init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --password **** --mlss_id 548 --output_dir /lustre/scratch101/ensembl/kb3/scratch/hive/release_65/emf_dumps/epo_6_primate --species human -dbname dumpMultiAlign_6way_primate_65 -pipeline_name DUMP_6_65
#3.4 hours
#
#epo 12 way
#init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --password **** --mlss_id 547 --output_dir /lustre/scratch101/ensembl/kb3/scratch/hive/release_65/emf_dumps/epo_12_eutherian --species human -dbname dumpMultiAlign_12way_eutherian_65 -pipeline_name DUMP_12_65
#2.7 hours
#
#mercator/pecan 19 way
#init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --password **** --mlss_id 50035 --output_dir /lustre/scratch101/ensembl/kb3/scratch/hive/release_65/emf_dumps/pecan_19_amniota --species human -dbname dumpMultiAlign_19way_amniota_65 -pipeline_name DUMP_19_65
#5.5 hours
#
#low coverage epo 35 way
#init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --password **** --mlss_id 50036 --output_dir /lustre/scratch101/ensembl/kb3/scratch/hive/release_65/emf_dumps/epo_35_eutherian --species human --high_coverage_mlss_id 547 -dbname dumpMultiAlign_35way_eutherian_65 -pipeline_name DUMP_35_65
#43 hours (1.8 days)
#

package Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

	'release'       => 74,
        'pipeline_name' => 'DUMP_'.$self->o('release'),  # name used by the beekeeper to prefix job names on the farm

        'dbname' => 'dumpMultiAlign'.$self->o('release'),  # database suffix (without user name prepended)

        'pipeline_db' => {                               # connection parameters
            -driver => 'mysql',
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_'.$self->o('dbname'),
        },

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -driver => 'mysql',
	    -dbname => $self->o('release'),
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -driver => 'mysql',
	    -dbname => $self->o('release'),
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -driver => 'mysql',
        },

	#Location of core and, optionally, compara db
	'db_urls' => [ $self->dbconn_2_url('staging_loc1'), $self->dbconn_2_url('staging_loc2') ],

	#Alternative method of defining location of dbs
	'reg_conf' => '',

	#Default compara. Can be the database name (if loading via db_urls) or the url
	'compara_db' => 'Multi',

	'species'  => "human",
        'coord_system_name1' => "chromosome",
        'coord_system_name2' => "supercontig",
	'split_size' => 200,
	'masked_seq' => 1,
        'format' => 'emf',
        'dump_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/DumpMultiAlign.pl",
        'emf2maf_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/emf2maf.pl",
	'maf_output_dir' => "",
	'species_tree_file' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/species_tree_blength.nh",
	'high_coverage_mlss_id' => "",
        'memory_suffix' => "", #temporary fix to define the memory requirements in resource_classes

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

	#Store DumpMultiAlign other_gab genomic_align_block_ids
        'mysql ' . $self->dbconn_2_mysql('pipeline_db', 1) . " -e 'CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL)'",

	#Store DumpMultiAlign healthcheck results
        'mysql ' . $self->dbconn_2_mysql('pipeline_db', 1) . " -e 'CREATE TABLE healthcheck (filename VARCHAR(400) NOT NULL, expected INT NOT NULL, dumped INT NOT NULL)'",
	
	'mkdir -p '.$self->o('output_dir'), #Make dump_dir directory
    ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
	    'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
    };
}


sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '2GbMem' => { 'LSF' => '-C0 -M2000' . $self->o('memory_suffix') .' -R"select[mem>2000] rusage[mem=2000]"' },  
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
	 {  -logic_name => 'initJobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs',
            -parameters => {'species' => $self->o('species'),
			    'dump_mlss_id' => $self->o('mlss_id'),
			    'output_dir' => $self->o('output_dir'),
			    'compara_db' => $self->o('compara_db'),
			    'db_url'    =>  $self->o('db_urls'),
			    'reg_conf' => $self->o('reg_conf'),
			    'maf_output_dir' => $self->o('maf_output_dir'), #define if want to run emf2maf 
			   },
            -input_ids => [ {} ],
            -flow_into => {
                2 => [ 'createChrJobs' ],   
                3 => [ 'createSuperJobs'  ],  
		4 => [ 'createOtherJobs' ],
		1 => [ 'md5sum'],
		5 => [ 'md5sum'], #if defined maf_output_dir
            },
        },
	 {  -logic_name    => 'createChrJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs',
            -parameters    => {'coord_system_name' => $self->o('coord_system_name1'),
			       'format' => $self->o('format'),
			       'compara_db' => $self->o('compara_db'),
			       'db_url'    =>  $self->o('db_urls'),
			       'reg_conf' => $self->o('reg_conf'),
			       'split_size' => $self->o('split_size'),
			      },
            -input_ids     => [
			      ],
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ] #must be on branch2 incase there are no results
            }	    
        },
	{  -logic_name    => 'createSuperJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs',
            -parameters    => {'coord_system_name' => $self->o('coord_system_name2'),
                               'format' => $self->o('format'),
			       'output_dir' => $self->o('output_dir'),
			       'compara_db' => $self->o('compara_db'),
			       'db_url'    =>  $self->o('db_urls'),
			       'reg_conf' => $self->o('reg_conf'),
			      },
            -input_ids     => [
            ],
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ]
            }
        },
	{  -logic_name    => 'createOtherJobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateOtherJobs',
            -parameters    => {'species' => $self->o('species'),
			       'format' => $self->o('format'),
			       'compara_db' => $self->o('compara_db'),
			       'reg_conf' => $self->o('reg_conf'),
			       'db_url'    =>  $self->o('db_urls'),
			       'split_size' => $self->o('split_size'),
			      },
            -input_ids     => [
            ],
	   -rc_name => '2GbMem',
	   -hive_capacity => 10, #make this large to allow any dumpMultiAlign jobs to start
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ]
            }
        },
	{  -logic_name    => 'dumpMultiAlign',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign',

            -parameters    => {"cmd"=>"perl " . $self->o('dump_program') . " --species " . $self->o('species') . " --mlss_id " . $self->o('mlss_id') ." --coord_system " . "#coord_system# --masked_seq " . $self->o('masked_seq') . " --split_size " . $self->o('split_size') . " --output_format " . $self->o('format') . "  #extra_args#", 
			       "reg_conf" => $self->o('reg_conf'),
			       "db_urls" => $self->o('db_urls'),
			       "compara_db" => $self->o('compara_db'),
			       "num_blocks"=> "#num_blocks#",
			       "output_dir"=> $self->o('output_dir'),
			       "output_file"=>"#output_file#" , 
			       "dumped_output_file"=>"#dumped_output_file#" , 
			       "format" => $self->o('format'), 
			       "maf_output_dir" => $self->o('maf_output_dir'),
			      },
            -input_ids     => [
            ],
	   -hive_capacity => 15,
	   -rc_name => '2GbMem',
	    -flow_into => {
	       2 => [ 'emf2maf' ],
	       1 => [ 'compress' ]
            }
        },
	{  -logic_name    => 'emf2maf',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf',
            -parameters    => {"output_dir"=> $self->o('output_dir'), 
			       "emf2maf_program" => $self->o('emf2maf_program'), 
			       "maf_output_dir" => $self->o('maf_output_dir')},
            -input_ids     => [
            ],
	   -can_be_empty  => 1,
	   -hive_capacity => 200,
	   -flow_into => {
	       2 => [ 'compress' ],
           }
        },
	{  -logic_name    => 'compress',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Compress',
            -parameters    => {"output_dir"=> $self->o('output_dir')},
            -input_ids     => [
            ],
	   -hive_capacity => 200,
        },
	{  -logic_name    => 'md5sum',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MD5SUM',
            -parameters    => {'output_dir' => $self->o('output_dir'),},
            -input_ids     => [
            ],
	    -wait_for => [ 'dumpMultiAlign', 'compress' ],
        },
	{  -logic_name    => 'readme',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Readme',
            -parameters    => {'format' => $self->o('format'),
			       'compara_db' => $self->o('compara_db'),
			       'reg_conf' => $self->o('reg_conf'),
			       'db_url'    =>  $self->o('db_urls'),
			       'mlss_id' => $self->o('mlss_id'),
			       'output_dir' => $self->o('output_dir'),
			       'split_size' => $self->o('split_size'),
			       'species_tree_file' => $self->o('species_tree_file'),
			       'species' => $self->o('species'),
			       'high_coverage_mlss_id' =>$self->o('high_coverage_mlss_id') ,
			      },
            -input_ids     =>[ 
		  {
		  },
             ],
        },    

    ];
}

1;
