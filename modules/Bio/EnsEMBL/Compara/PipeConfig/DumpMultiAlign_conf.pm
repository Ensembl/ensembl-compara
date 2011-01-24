## Configuration file for DumpMultiAlign pipeline

package Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/src/ensembl_main/', 
	'release'       => 61,
        'pipeline_name' => 'DUMP_'.$self->o('release'),  # name used by the beekeeper to prefix job names on the farm

        'dbname' => 'dumpMultiAlign'.$self->o('release'),  # database suffix (without user name prepended)

        'pipeline_db' => {                               # connection parameters
            -host   => 'compara4',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $ENV{USER}.'_'.$self->o('dbname'),
        },
	'core_url' => "",
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
	'species_tree_data_id' => "",
	'high_coverage_mlss_id' => "",
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
	
    ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
	    'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
    };
}


sub resource_classes {
    my ($self) = @_;
    return {
         0 => { -desc => 'default, 8h',      'LSF' => '' },
	 1 => { -desc => 'urgent',           'LSF' => '-q yesterday' },
         2 => { -desc => 'compara1',         'LSF' => '-R"select[mycompara1<800] rusage[mycompara1=10:duration=3]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
	 {  -logic_name => 'initJobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs',
            -parameters => {'species' => $self->o('species'),
			    'format' => $self->o('format'),
			    'dump_mlss_id' => $self->o('dump_mlss_id'),
			    'output_dir' => $self->o('output_dir'),
			    'compara_dbname' => $self->o('compara_dbname'),
			    'reg_conf' => $self->o('reg_conf'),
			    'split_size' => $self->o('split_size'),
			    'masked_seq' => $self->o('masked_seq'),
			    'dump_program' => $self->o('dump_program'),
			    'emf2maf_program' => $self->o('emf2maf_program'),
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
			       'output_dir' => $self->o('output_dir'),
			       'compara_dbname' => $self->o('compara_dbname'),
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
			       'compara_dbname' => $self->o('compara_dbname'),
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
			       'output_dir' => $self->o('output_dir'),
			       'compara_dbname' => $self->o('compara_dbname'),
			       'reg_conf' => $self->o('reg_conf'),
			       'split_size' => $self->o('split_size'),
			      },
            -input_ids     => [
            ],
	   -hive_capacity => 10, #make this large to allow any dumpMultiAlign jobs to start
	    -flow_into => {
	       2 => [ 'dumpMultiAlign' ]
            }
        },
	{  -logic_name    => 'dumpMultiAlign',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign',
            -parameters    => {"cmd"=>"perl " . $self->o('dump_program') . " --reg_conf " .  $self->o('reg_conf') .  " --dbname " . $self->o('compara_dbname') . " --species " . $self->o('species') . " --mlss_id " . $self->o('dump_mlss_id') ." --coord_system " . "#coord_system# --masked_seq " . $self->o('masked_seq') . " --split_size " . $self->o('split_size') . " --output_format " . $self->o('format') . "  #extra_args#", 
			       "num_blocks"=> "#num_blocks#",
			       "output_dir"=> $self->o('output_dir'),
			       "output_file"=>"#output_file#" , 
			       "dumped_output_file"=>"#dumped_output_file#" , 
			       "format" => $self->o('format'), 
			       #"emf2maf_program" => $self->o('emf2maf_program'), 
			       "maf_output_dir" => $self->o('maf_output_dir'),
			      },
            -input_ids     => [
            ],
	   -hive_capacity => 15,
	   -rc_id => 2,
	    -flow_into => {
	       2 => [ 'emf2maf' ],
	       1 => [ 'compress' ]
            }
        },
	{  -logic_name    => 'emf2maf',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf',
            -parameters    => {"output_dir"=> $self->o('output_dir'), "emf2maf_program" => $self->o('emf2maf_program'), "maf_output_dir" => $self->o('maf_output_dir')},
            -input_ids     => [
            ],
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
	   -wait_for => [ 'emf2maf' ],
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
			       'reg_conf' => $self->o('reg_conf'),
			       'compara_dbname' => $self->o('compara_dbname'),
			       'mlss_id' => $self->o('dump_mlss_id'),
			       'output_dir' => $self->o('output_dir'),
			       'split_size' => $self->o('split_size'),
			       'species_tree_file' => $self->o('species_tree_file'),
			       'species_tree_data_id' => $self->o('species_tree_data_id'),
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
