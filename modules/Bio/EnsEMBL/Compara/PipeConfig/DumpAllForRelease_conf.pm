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
use Data::Dumper;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

use Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf;
use Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpMultiAlign;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConservationScores;

sub default_options {
    my ($self) = @_;
    my $do = {
        %{$self->SUPER::default_options},
        %{ Bio::EnsEMBL::Compara::PipeConfig::DumpTrees_conf::default_options($self) },
        %{ Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf::default_options($self) },

        ######################################################
        # Review these options prior to running each release #
        ######################################################
        
        'curr_release' => $ENV{CURR_ENSEMBL_RELEASE},
        'dump_root'    => '/hps/nobackup2/production/ensembl/'.$ENV{'USER'}.'/release_dumps_#curr_release#',
        'ftp_root'     => '/gpfs/nobackup/ensembl/carlac/fake_ftp', # USE THIS PATH FOR RELEASE 93 ONLY !!
        # 'ftp_root'     => '/nfs/production/panda/ensembl/production/ensemblftp/',

        'reg_conf'     => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl',
        'compara_db'   => 'compara_curr', # can be URL or reg alias
        'ancestral_db' => 'ancestral_curr',

        # were there lastz patches this release? pass hive pipeline urls if yes, pass undef if no
        #  'lastz_patch_dbs' => [
        #  	'mysql://ensro@mysql-ens-compara-prod-3:4523/carlac_lastz_human_patches_92',
		#   'mysql://ensro@mysql-ens-compara-prod-3:4523/carlac_lastz_mouse_patches_92',
        #  ],
        'lastz_patch_dbs' => undef,

        ######################################################
        ######################################################


        # ----------------------------------------------------- #
        # the following options should remain largely unchanged #
        # ----------------------------------------------------- #

        # capacities for heavy-hitting jobs
		'dump_aln_capacity'   => 80,
		'dump_trees_capacity' => 10,
		'dump_ce_capacity'    => 10,
    	'dump_cs_capacity'    => 20,
    	'dump_hom_capacity'   => 2, 
        'dump_per_genome_cap' => 10,


    	# general settings
        'pipeline_name'   => 'dump_all_for_release_#curr_release#',
        'rel_with_suffix' => '#curr_release#',
        'division'        => 'ensembl',
        'dump_dir'        => '#dump_root#/release-#curr_release#',
		'lastz_dump_path' => 'maf/ensembl-compara/pairwise_alignments', # where, from the FTP root, is the LASTZ dumps?       
        'reuse_prev_rel'  => 1, # copy symlinks from previous release dumps

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
        		compara_db       => '#compara_db#', 
        		registry         => '#reg_conf#',
        		curr_release     => '#curr_release#',
         		make_tar_archive => 0,
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
        		target_dir           => '#dump_root#/release-#curr_release#',
        		base_dir             => '#dump_root#',
        		work_dir             => '#dump_root#/dump_hash',
        		emf_dir              => $self->o('emf_dir'),
        		xml_dir              => $self->o('xml_dir'),
        		tsv_dir              => $self->o('tsv_dir'),
        	},
        	DumpSpeciesTrees => {
        		compara_url => '#compara_db#',
        		dump_dir    => '#dump_dir#/compara/species_trees',
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
        	LASTZ_NET => ['maf/ensembl-compara/pairwise_alignments'],
        	EPO => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	EPO_LOW_COVERAGE => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	PECAN => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	GERP_CONSTRAINED_ELEMENT => ['bed/ensembl-compara'],
        	GERP_CONSERVATION_SCORE => ['compara/conservation_scores'],
        },

        # tree dump options
        'clusterset_id' => undef,
        'member_type'   => undef,
        
        # constrained elems & conservation scores
        'big_wig_exe'           => $self->check_exe_in_cellar('kent/v335_1/bin/bedGraphToBigWig'),
        'dump_features_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'cs_readme'             => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/docs/ftp/conservation_scores.txt",
    	'ce_readme'             => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/docs/ftp/constrained_elements.txt",

    	# species tree options
    	'dump_species_tree_exe'  => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/examples/species_getSpeciesTree.pl',

    	# ancestral alleles
    	'ancestral_dump_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl",
		'ancestral_stats_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/ancestral_sequences/get_stats.pl",

    };
    return $do;
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}

sub pipeline_create_commands {
    my $self = shift;

    return [
        @{ $self->SUPER::pipeline_create_commands },
        $self->db_cmd( 'CREATE TABLE other_gab (genomic_align_block_id bigint NOT NULL)' ),
        $self->db_cmd( 'CREATE TABLE healthcheck (filename VARCHAR(400) NOT NULL, expected INT NOT NULL, dumped INT NOT NULL)' ),
    ];
}

# sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'reg_conf'        => $self->o('reg_conf'),
        'registry'        => $self->o('reg_conf'),
        'curr_release'    => $self->o('curr_release'),
        'rel_with_suffix' => $self->o('curr_release'),
        'dump_root'       => $self->o('dump_root' ),
        'dump_dir'        => $self->o('dump_dir'),
        'ftp_root'        => $self->o('ftp_root'),  
        'division'        => $self->o('division'),

        # tree params
        'dump_trees_capacity' => $self->o('dump_trees_capacity'),
        'dump_hom_capacity'   => $self->o('dump_hom_capacity'),
        'dump_per_genome_cap' => $self->o('dump_per_genome_cap'),
        'basename'            => '#member_type#_#clusterset_id#',
        'name_root'           => 'Compara.'.$self->o('rel_with_suffix').'.#basename#',

        # ancestral alleles
        'anc_output_dir' => "#dump_dir#/fasta/ancestral_alleles",
        'ancestral_dump_program' => $self->o('ancestral_dump_program'),
        'ancestral_stats_program' => $self->o('ancestral_stats_program'),

        # constrained elems & conservation scores
        'dump_cs_capacity'      => $self->o('dump_cs_capacity'),
        'dump_ce_capacity'      => $self->o('dump_ce_capacity'),
        'dump_features_program' => $self->o('dump_features_program'),
        'cs_readme'             => $self->o('cs_readme'),
        'ce_readme'             => $self->o('ce_readme'),
        
        'export_dir'     => $self->o('dump_dir'),
        'ce_output_dir'  => '#export_dir#/bed/ensembl-compara/#dirname#',
        'cs_output_dir'  => '#export_dir#/compara/conservation_scores/#dirname#',
        'work_dir'       => '#dump_root#/dump_hash',

        'bedgraph_file'  => '#cs_output_dir#/gerp_conservation_scores.#name#.bedgraph',
        'chromsize_file' => '#work_dir#/#dirname#/gerp_conservation_scores.#name#.chromsize',
        'bigwig_file'    => '#cs_output_dir#/gerp_conservation_scores.#name#.bw',
        'bed_file'       => '#ce_output_dir#/gerp_constrained_elements.#name#.bed',

        # species trees
        'dump_species_tree_exe'  => $self->o('dump_species_tree_exe'),

        # dump alignments + aln patches
        'dump_aln_capacity'   => $self->o('dump_aln_capacity'),
        'split_size'          => $self->o('split_size'),
        'masked_seq'          => $self->o('masked_seq'),
        'dump_aln_program'    => $self->o('dump_aln_program'),
        'emf2maf_program'     => $self->o('emf2maf_program'),
        # 'make_tar_archive'    => '#make_tar_archive#',
        'split_by_chromosome' => $self->o('split_by_chromosome'),
        'output_dir'          => '#export_dir#/#format#/ensembl-compara/#aln_type#/#base_filename#',
        'output_file_gen'     => '#output_dir#/#base_filename#.#region_name#.#format#',
        'output_file'         => '#output_dir#/#base_filename#.#region_name##filename_suffix#.#format#',
    }
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'default'  => {'LSF' => [ '', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ]  },
	    'default_with_registry'  => {'LSF' => [ '', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ]  },
	    '1Gb_job'  => {'LSF' => [ '-C0 -M1000  -R"select[mem>1000]  rusage[mem=1000]"', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ] },
	    '2Gb_job'  => {'LSF' => [ '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ] },
	    '2Gb_job_long'  => {'LSF' => [ '-q long -C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ] },
	    '4Gb_job'  => {'LSF' => [ '-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ] },
	    '10Gb_job' => {'LSF' => [ '-C0 -M10000  -R"select[mem>10000]  rusage[mem=10000]"', $reg_requirement ], 'LOCAL' => [ '', $reg_requirement ] },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my @all_pa = (
        {   -logic_name => 'create_all_dump_jobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CreateDumpJobs',
            -input_ids  => [ {
                    'compara_db'           => $self->o('compara_db'),
                    'curr_release'         => $self->o('curr_release'),
                    'reuse_prev_rel'       => $self->o('reuse_prev_rel'),
                    'reg_conf'             => $self->o('reg_conf'),
                    'dump_dir'             => $self->o('dump_dir'),

                    'lastz_patch_dbs'      => $self->o('lastz_patch_dbs'),
                    'align_dump_options'   => $self->o('align_dump_options'),
                    'default_dump_options' => $self->o('default_dump_options'),
                    'ancestral_db'         => $self->o('ancestral_db'),
                } ],
            -flow_into  => {
                '1'    => [ 'DumpMultiAlign_start' ],
                '2'    => { 'DumpTrees_start' => INPUT_PLUS() }, 
                '3'    => [ 'DumpConstrainedElements_start' ], 
                '4'    => [ 'DumpConservationScores_start'  ], 
                '5'    => [ 'DumpSpeciesTrees_start'        ], 
                '6'    => [ 'DumpAncestralAlleles_start'    ],
                '7'    => [ 'DumpMultiAlignPatches_start'   ],
                '8'    => [ 'create_ftp_skeleton'           ],
            },
        },

        #------------------------------------------------------------------#
        # create dummy analyses to make it clearer which pipeline is which #
        # and to pass any additional pipeline-specific parameters          #
        #------------------------------------------------------------------#
        {	-logic_name => 'DumpMultiAlign_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-flow_into  => [ 'DumpMultiAlign_MLSSJobFactory' ],
        },
        {	-logic_name => 'DumpTrees_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-parameters => { 
        		# 'basename'  => '#member_type#_#clusterset_id#',
		        # 'name_root' => 'Compara.'.$self->o('rel_with_suffix').'.#basename#',
		        'base_dir'  => '#dump_dir#',
		        'work_dir'  => '#work_dir#/trees_#curr_release#',
		    },
        	-flow_into => [ 'dump_trees_pipeline_start' ],
        },
        {	-logic_name => 'DumpConstrainedElements_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-parameters => {
        		'work_dir' => '#work_dir#/constrained_elements_#curr_release#',
        	},
        	-flow_into  => [ 'mkdir_constrained_elems' ],
        },
        {	-logic_name => 'DumpConservationScores_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-parameters => {
        		'export_dir' => '#dump_dir#',
        		'work_dir'   => '#work_dir#/conservation_scores_#curr_release#',
        	},
        	# -flow_into  => { 1 => {'mkdir_conservation_scores' => INPUT_PLUS()} },
        	-flow_into => [ 'mkdir_conservation_scores' ],
        },
        {	-logic_name => 'DumpSpeciesTrees_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-flow_into  => ['mk_species_trees_dump_dir' ],
        },
        {	-logic_name => 'DumpAncestralAlleles_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-flow_into  => [ 'mk_ancestral_dump_dir' ],
        },
        {	-logic_name => 'DumpMultiAlignPatches_start',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        	-flow_into  => {
        		'1->A' => [ 'DumpMultiAlign_MLSSJobFactory' ],
        		'A->1' => { 'patch_lastz_dump' => { mlss_id => '#mlss_id#', compara_db => '#compara_db#' } },
        	},
        },
        
       #------------------------------------------------------------------#


        {	-logic_name => 'create_ftp_skeleton',
        	-module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FTPSkeleton',
        	-parameters => {
        		'ftp_locations' => $self->o('ftp_locations'),
        		'dump_dir'      => $self->o('dump_dir'     ),
        	},
        	-flow_into => [ 'symlink_prev_dumps' ],
        },

        {	-logic_name => 'symlink_prev_dumps',
        	-module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::SymlinkPreviousDumps',
        	-parameters => {
        		'curr_release' => $self->o('curr_release'),
        		'ftp_root'     => $self->o('ftp_root'    ),
        		'dump_dir'     => $self->o('dump_dir'    ),
        	},
        	-flow_into => ['create_all_dump_jobs'], # to top up any missing dumps
        },

        {   -logic_name => 'patch_lastz_dump',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchLastzDump',
            -parameters => {
            	'lastz_dump_path' => $self->o('lastz_dump_path'),
            	'curr_release'    => $self->o('curr_release'   ),
            	'compara_db'      => $self->o('compara_db'),
            	'ftp_root'        => $self->o('ftp_root'       ),
            },
            -rc_name => 'default_with_registry',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpMultiAlign::pipeline_analyses_dump_multi_align($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees::pipeline_analyses_dump_species_trees($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles::pipeline_analyses_dump_anc_alleles($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements::pipeline_analyses_dump_constrained_elems($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConservationScores::pipeline_analyses_dump_conservation_scores($self) },
    
    );

	# add DumpTree analyses seperately in order to set the collection_factory parameters
    my $tree_pa = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpTrees::pipeline_analyses_dump_trees($self);
    $tree_pa->[1]->{'-parameters'} = {
        'inputquery'    => 'SELECT clusterset_id, member_type FROM gene_tree_root WHERE tree_type = "tree" AND ref_root_id IS NULL GROUP BY clusterset_id, member_type',
        'db_conn'       => '#rel_db#',
    };
    push( @all_pa, @$tree_pa );
    return \@all_pa;
}

1;
