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

##
## Configuration file for DumpMultiAlign pipeline
package Bio::EnsEMBL::Compara::PipeConfig::Example::EGDumpMultiAlign_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Version 2.2;
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones
		'release'       => $self->o('ensembl_version'),
        'pipeline_name' => '',#'dumpMultiAlign_'.$self->o('release'),  # name used by the beekeeper to prefix job names on the farm
        'dbname' 		=> '',#dumpMultiAlign_'.$self->o('release'),  # database suffix (without user name prepended)

       'pipeline_db' => {  
		     -host   => $self->o('hive_host'),
        	 -port   => $self->o('hive_port'),
        	 -user   => $self->o('hive_user'),
        	 -pass   => $self->o('hive_password'),
	         -dbname => $self->o('hive_dbname'),
        	 -driver => 'mysql',
      	},

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'mysql-eg-staging-1',
            -port   => 4260,
            -user   => 'ensro',
            -pass   => '',
		    -driver => 'mysql',
		    -dbname => $self->o('release'),
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'mysql-eg-staging-2',
            -port   => 4275,
            -user   => 'ensro',
            -pass   => '',
	        -driver => 'mysql',
	        -dbname => $self->o('release'),
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'mysql-eg-mirror.ebi.ac.uk',
            -port   => 4157,
            -user   => 'ensrw',
            -pass   => 'writ3r',
            -driver => 'mysql',
            -dbname => $self->o('release'), ## 
        },

	#Location of core and, optionally, compara db
	'db_urls' => [ $self->dbconn_2_url('livemirror_loc') ],

	#Alternative method of defining location of dbs
	'reg_conf' => '',

	#Default compara. Can be the database name (if loading via db_urls) or the url
#	'compara_db' => 'Multi',
	'compara_db' 		 => '',
	'species'  			 => "",
    'coord_system_name1' => "chromosome",
    'coord_system_name2' => "supercontig",
	'split_size' 		 => 0, #200,
	'masked_seq' 		 => 1,
    'format' 			 => 'emf',

    'dump_program'    => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/DumpMultiAlign.pl",
    'emf2maf_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/emf2maf.pl",

	'maf_output_dir'        => "",
	'species_tree_file'     => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/species_tree_blength.nh",
	'high_coverage_mlss_id' => "",
    'memory_suffix'         => "", #temporary fix to define the memory requirements in resource_classes

	 # Method link types of mlss_id to retrieved	 
     'method_link_types' => ['BLASTZ_NET', 'TRANSLATED_BLAT', 'TRANSLATED_BLAT_NET', 'LASTZ_NET'],
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation

		#'mkdir -p '.$self->o('output_dir'), #Make dump_dir directory
    ];
}

# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

#sub beekeeper_extra_cmdline_options {
#  my ($self) = @_;
  
#  return 
#    ' -reg_conf ' . $self->o('registry')
#  ;
#}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
    my ($self) = @_;

	my $options = join(' ', $self->SUPER::beekeeper_extra_cmdline_options, "-reg_conf ".$self->o('registry'));
	
return $options;
}


sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
	    'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
    };
}


sub resource_classes {
    my $self = shift;
    return {
      '8GbMem'  	 	=> {'LSF' => '-q production-rh6 -n 4 -M 8000 -R "rusage[mem=8000]"'},
      'default'  	 	=> {'LSF' => '-q production-rh6 -n 4 -M 4000 -R "rusage[mem=4000]"'},
	}
}


sub pipeline_analyses {
    my ($self) = @_;
    return [
      { -logic_name    => 'backbone_fire_DumpMultiAlign',
  	    -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
    	-input_ids     => [ {} ], 
        -parameters    => {
                		   cmd => 'mkdir -p ' . $self->o('output_dir'),
         			      },
        -hive_capacity => -1,
        -flow_into 	   => { 
 					 	    '1'=> ['createTables'],
       	 		           },
      },   

      { -logic_name    => 'createTables',
        -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
        -parameters    => {
				 	 	   #Store DumpMultiAlign other_gab genomic_align_block_ids
		 				   #Store DumpMultiAlign healthcheck results
		                   'sql' => [ 'CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL)',
          			                  'CREATE TABLE healthcheck (filename VARCHAR(400) NOT NULL, expected INT NOT NULL, dumped INT NOT NULL)',
                		    ],
            			  },
       -flow_into      => {
			                 '2->A' => ['MLSSJobFactory'],
			                 'A->1' => ['createREADME'],		                       
                          },
      },

 	  { -logic_name    => 'MLSSJobFactory',
        -module        => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory',
        -parameters    => {
							'division'          => $self->o('compara_db'),
							'method_link_types' => $self->o('method_link_types'),
                           },
       -rc_name        => 'default',
       -flow_into      => {
			                 '2' => ['initJobs'],
                           },
     },
     
	 { -logic_name     => 'createREADME',
       -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MafReadme',
       -parameters     => {
			    	  	   'output_dir' 	 => $self->o('output_dir'),
				     	  },
     },    

	 { -logic_name 	   => 'initJobs',
       -module     	   => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs',
       -parameters 	   => {
			    			'output_dir' 	 => $self->o('output_dir'),
			    			'compara_db' 	 => $self->o('compara_db'),
			    			'db_url'     	 => $self->o('db_urls'),
			    			'reg_conf'   	 => $self->o('reg_conf'),
			    			'maf_output_dir' => $self->o('maf_output_dir'), #define if want to run emf2maf 
			   			  },
       -flow_into 	   => {
			                 '2->A' => ['ChrJobsFactory', 'SuperJobsFactory'],
			                 'A->1' => ['archiveMAF'],		                       
      				 	  },
    },
     
	# Generates DumpMultiAlign jobs from genomic_align_blocks on chromosomes. 
	{ -logic_name  	   => 'ChrJobsFactory',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::ChrJobsFactory',
      -parameters      => {
            	   			'coord_system_name' => $self->o('coord_system_name1'),
			       			'format' 		    => $self->o('format'),
			       			'compara_db' 	    => $self->o('compara_db'),
			       			'db_url'    		=> $self->o('db_urls'),
			       			'reg_conf' 		    => $self->o('reg_conf'),
	 	     	          },
	  -flow_into   	   => {
	       				 	2 => [ 'dumpMultiAlign' ] 
        			      }	    
    },

    # Generates DumpMultiAlign jobs from genomic_align_blocks on supercontigs. 
	{ -logic_name      => 'SuperJobsFactory',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::SuperJobsFactory',
      -parameters      => {
      					 	'coord_system_name' => $self->o('coord_system_name2'),
                         	'format' 			=> $self->o('format'),
			       	 	 	'compara_db' 		=> $self->o('compara_db'),
			       		 	'db_url'    		=> $self->o('db_urls'),
			       		 	'reg_conf' 		 	=> $self->o('reg_conf'),
	  			         	'output_dir' 		=> $self->o('output_dir'),
			      	      },
	  -flow_into   	   => {
	       			 		2 => [ 'dumpMultiAlign' ]
            		      }
    },

	# Generates DumpMultiAlign jobs from genomic_align_blocks
    # on the chromosomes which do not contain species. 
#	{  -logic_name     => 'createOtherJobs',
#       -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateOtherJobs',
#       -parameters     => {
#       					'species'    => $self->o('species'),
#			       		    'format'     => $self->o('format'),
#			       		    'compara_db' => $self->o('compara_db'),
#			       		    'reg_conf'   => $self->o('reg_conf'),
#			       		    'db_url'     => $self->o('db_urls'),
#			       		    'split_size' => $self->o('split_size'),
#			      		  },
#       -input_ids      => [],
#	   -rc_name        => '8GbMem',
#	   -hive_capacity  => 10, #make this large to allow any dumpMultiAlign jobs to start
#	   -flow_into      => {
#	       				   2 => [ 'dumpMultiAlign' ]
#             		      }
#    },
    
	{ -logic_name      => 'dumpMultiAlign',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign',
      -parameters      => {
#            	   		   "cmd"        		=> "perl " . $self->o('dump_program') . " --species " . "#species# --mlss_id " . "#mlss_id# --coord_system " . "#coord_system# --masked_seq " . $self->o('masked_seq') . " --split_size " . $self->o('split_size') . " --output_format " . $self->o('format') . "  #extra_args#", 
            	   		   "cmd"        		=> "perl " . $self->o('dump_program') . " --species " . "#species# --mlss_id " . "#mlss_id# --coord_system " . "#coord_system# --masked_seq " . $self->o('masked_seq') . " --output_format " . $self->o('format') . "  #extra_args#", 
			       		   "reg_conf"   		=> $self->o('reg_conf'),
			       		   "db_urls"    		=> $self->o('db_urls'),
			       		   "compara_db" 		=> $self->o('compara_db'),
			       		   "num_blocks" 		=> "#num_blocks#",
			       		   "output_dir" 		=> $self->o('output_dir'),
			       		   "output_file"		=>"#output_file#" , 
			       		   "dumped_output_file" =>"#dumped_output_file#" , 
			       		   "format"             => $self->o('format'), 
			       		   "maf_output_dir"     => $self->o('maf_output_dir'),
			      		 },
	  -hive_capacity   => 100, 
	  -rc_name         => '8GbMem',
	  -flow_into       => {
	      				    2 => [ 'emf2maf' ],
            			   }
    },

	{ -logic_name      => 'emf2maf',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf',
      -parameters      => {
       					   "output_dir"      => $self->o('output_dir'), 
			       		   "emf2maf_program" => $self->o('emf2maf_program'), 
			       		   "maf_output_dir"  => $self->o('maf_output_dir')
			       		  },
	  -can_be_empty    => 1,
	  -hive_capacity   => 200,
    },

	{ -logic_name      => 'archiveMAF',
	  -module 		   => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::archiveMAF',
      -parameters      => {
     					   "output_dir"=> $self->o('output_dir'),
      					  },
	  -hive_capacity   => 10,
    },

    ];
}

1;
