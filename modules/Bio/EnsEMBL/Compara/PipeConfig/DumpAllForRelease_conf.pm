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

Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf

=head1 DESCRIPTION

The PipeConfig file for the pipeline that performs FTP dumps of everything required for a
given release. It will detect which pipelines have been run and dump anything new.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

use Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf;
use Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;
use Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf;
use Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf;
use Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf;
use Bio::EnsEMBL::Compara::PipeConfig::DumpConservationScores_conf;

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        %{ Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf::default_options($self) },
        %{ Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf::default_options($self) },
        # %{ Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf::default_options($self) },
        # %{ Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf::default_options($self) },
        # %{ Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf::default_options($self) },
        # %{ Bio::EnsEMBL::Compara::PipeConfig::DumpConservationScores_conf::default_options($self) },


        'curr_release' => $ENV{CURR_ENSEMBL_RELEASE},

        'dump_dir'     => '/hps/nobackup/production/ensembl/'.$ENV{'USER'}.'/dumps_#curr_release#',
        'ftp_root'     => '/nfs/production/panda/ensembl/production/ensemblftp/',

        'reg_conf'     => '/homes/carlac/src/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl',
        'compara_db'   => 'compara_curr',
        'ancestral_db' => 'ancestral_curr',

        # 'lastz_patch_dbs' => [
        # 	'mysql://ensadmin:ensembl@mysql-ens-compara-prod-3:4523/carlac_lastz_human_patches_92',
		# 	'mysql://ensadmin:ensembl@mysql-ens-compara-prod-3:4523/carlac_lastz_mouse_patches_92',
        # ],
        'lastz_patch_dbs' => undef,
		'lastz_dump_path' => 'maf/ensembl-compara/pairwise_alignments', # where, from the FTP root, is the        

		# define input options for DumpMultiAlign for each method_link_type
		'align_dump_options' => {
        	EPO              => {format => 'emf+maf'},
        	EPO_LOW_COVERAGE => {format => 'emf+maf'},
        	PECAN            => {format => 'emf+maf'},
        	LASTZ_NET        => {format => 'maf', make_tar_archive => 1},
        },

        # define which params should ALWAYS be passed to each dump pipeline
        'default_dump_options' => {
        	DumpMultiAlign          => { 
        		compara_db   => '#compara_db#', 
        		registry     => '#reg_conf#',
        		curr_release => '#curr_release#',
        	},
        	DumpConstrainedElements => { 
        		compara_url => '#compara_db#', 
        		registry    => '#reg_conf#', 
        	},
        	DumpConservationScores  => { 
        		compara_url => '#compara_db#', 
        		registry    => '#reg_conf#', 
        	},
        	DumpTrees               => { 
        		dump_per_species_tsv => 1, 
        		production_registry  => '--reg_conf #reg_conf#', 
        		rel_db               => '#compara_db#', 
        	},
        	DumpSpeciesTrees => {
        		compara_url => '#compara_db#',
        		dump_dir    => '#dump_dir#',
        	},
        	DumpAncestralAlleles => {
        		compara_db   => '#compara_db#',
        		dump_dir     => '#dump_dir#',
        		reg_conf     => '#reg_conf#',
        		ancestral_db => '#ancestral_db#',
        	},
        },

        # define which files will each method_type generate in the FTP structure
        # this will be used to generate a bash script to copy old data
        ftp_locations => {
        	LASTZ_NET => ['emf/ensembl-compara/pairwise_alignments', 'maf/ensembl-compara/pairwise_alignments'],
        	EPO => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	EPO_LOW_COVERAGE => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	PECAN => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	GERP_CONSTRAINED_ELEMENT => ['bed/ensembl-compara'],
        	GERP_CONSERVATION_SCORE => ['bed/ensembl-compara'],
        },

        ################
        # HACK FOR NOW #
        ################
        'clusterset_id' => undef,
        'member_type'   => undef,
        'big_wig_exe'   => $self->check_exe_in_cellar('kent/v335_1/bin/bedGraphToBigWig'),
    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}

# sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'curr_release' => '#curr_release#',
        'dump_dir'     => '#dump_dir#',
        'ftp_root'     => '#ftp_root#',        
    }
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'default'  => {'LSF' => [ '', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ]  },
	    'default_with_registry'  => {'LSF' => [ '', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ]  },
	    '1Gb_job'  => {'LSF' => [ '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ] },
	    '2Gb_job'  => {'LSF' => [ '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ] },
	    '2Gb_job_long'  => {'LSF' => [ '-q long -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ] },
	    '4Gb_job'  => {'LSF' => [ '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ] },
	    '10Gb_job' => {'LSF' => [ '-C0 -M10000  -R"select[mem>10000]  rusage[mem=10000]"', $self->o('reg_conf') ], 'LOCAL' => [ '', $self->o('reg_conf') ] },
    	'crowd' => { 'LSF' => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'create_all_dump_jobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CreateDumpJobs',
            -input_ids  => [ {
                    'compara_db'      => $self->o('compara_db'),
                    'curr_release'    => $self->o('curr_release'),
                    'reg_conf'        => $self->o('reg_conf'),
                    'lastz_patch_dbs' => $self->o('lastz_patch_dbs'),
                    'align_dump_options' => $self->o('align_dump_options'),
                    'default_dump_options' => $self->o('default_dump_options'),
                } ],
            -flow_into  => {
                '1'    => [ 'DumpMultiAlign_MLSSJobFactory' ], # DumpMultiAlign
                '2'    => [ 'dump_trees_pipeline_start'     ], # DumpTrees - DOUBLE CHECK HOW TO SEED THIS ONE!!
                '3'    => [ 'mkdir_constrained_elems'       ], # DumpConstrainedElements
                '4'    => [ 'mkdir_conservation_scores'     ], # DumpConservationScores
                '5'    => [ 'mk_species_trees_dump_dir'     ], # DumpSpeciesTrees
                '6'    => [ 'mk_ancestral_dump_dir'         ], # DumpAncestralAlleles
                '7->A' => [ 'DumpMultiAlign_MLSSJobFactory' ], # DumpMultiAlignPatches
                'A->8' => [ 'patch_lastz_mlss_factory'      ], # Patches funnel
                '9'    => [ 'create_copy_jobs'              ],
            },
        },

        {   -logic_name => 'create_copy_jobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CreateCopyJobs',
            -parameters => {
            	'curr_release'  => $self->o('curr_release' ),
            	'ftp_root'      => $self->o('ftp_root'     ),
            	'ftp_locations' => $self->o('ftp_locations'),
            	'reg_conf'      => $self->o('reg_conf'     ),
            	'dump_dir'      => $self->o('dump_dir'     ),
            }
        },

        {   -logic_name => 'patch_lastz_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchMLSSFactory',
            -parameters => { 'lastz_patch_dbs' => $self->o('lastz_patch_dbs') },
            -flow_into  => { 
            	'2->A' => [ 'patch_lastz_dump' ],
            	'A->1' => [ 'patch_funnel' ],
            },
        },

        {   -logic_name => 'patch_lastz_dump',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchLastzDump',
            -parameters => {
            	'lastz_dump_path' => $self->o('lastz_dump_path'),
            	'curr_release'    => $self->o('curr_release'   ),
            	'dump_dir'        => $self->o('dump_dir'       ),
            	'ftp_root'        => $self->o('ftp_root'       ),
            }
        },

        {	-logic_name => 'patch_funnel',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf::pipeline_analyses($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf::pipeline_analyses($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf::pipeline_analyses($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf::pipeline_analyses($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf::pipeline_analyses($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::DumpConservationScores_conf::pipeline_analyses($self) },
    
    ];
}

sub _pipeline_analyses {
	my $self = shift;
	return Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf::_pipeline_analyses($self);
}

1;
