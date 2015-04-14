=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Make sure that all default_options are set correctly, especially:
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options (eg if doing primate-primate alignments)
        bed_dir if running pairaligner_stats module

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --dbname hsap_ggor_lastz_64 --password <your_password) --mlss_id 536 --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor_nib_files/ --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --password <your_password> --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    The PipeConfig file for PairAligner pipeline that should automate most of the tasks. This is in need of further work, especially to deal with multiple pairs of species in the same database. Currently this is dealt with by using the same configuration file as before and the filename should be provided on the command line (--conf_file). 

    You may need to provide a registry configuration file if the core databases have not been added to staging (--reg_conf).

    A single pair of species can be run either by using a configuration file or by providing specific parameters on the command line and using the default values set in this file. On the command line, you must provide the LASTZ_NET mlss which should have been added to the master database (--mlss_id). The directory to which the nib files will be dumped can be specified using --dump_dir or the default location will be used. All the necessary directories are automatically created if they do not already exist. It may be necessary to change the pair_aligner_options default if, for example, doing primate-primate alignments. It is recommended that you provide a meaningful database name (--dbname). The username is automatically prefixed to this, ie -dbname hsap_ggor_lastz_64 will become kb3_hsap_ggor_lastz_64. A basic healthcheck is run and output is written to the job_message table. To write to the pairwise configuration database, you must provide the correct config_url. Even if no config_url is given, the statistics are written to the job_message table.


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EGPairAligner_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

	#'dbname'               => '', #Define on the command line. Compara database name eg hsap_ggor_lastz_64

         # dependent parameters:
        'pipeline_name'         => 'LASTZ_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'host'        => 'mysql-eg-prod-2.ebi.ac.uk',                        #separate parameter to use the resources aswell
        'pipeline_db' => {                                  # connection parameters
            -host   => 'mysql-eg-prod-2.ebi.ac.uk',
            -port   => 4239,
            -user   => 'ensrw',
            -pass   => $self->o('password'), 
	    -dbname => $self ->o('dbname'),
	    -driver => 'mysql',
#            -dbname => $ENV{USER}.'_'.$self->o('dbname'),    
        },

	'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',

	'staging_loc1' => {
            -host   => 'mysql-eg-staging-1.ebi.ac.uk',
            -port   => 4160,
            -user   => 'ensro',
            -pass   => '',
        },
        'staging_loc2' => {
            -host   => 'mysql-eg-staging-2.ebi.ac.uk',
            -port   => 4275,
            -user   => 'ensro',
            -pass   => '',
        },  
	 'prod_loc1' => {
            -host   => 'mysql-eg-prod-1.ebi.ac.uk',
            -port   => 4238,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => 74,
        },
	'livemirror_loc' => {
            -host   => 'mysql-eg-mirror.ebi.ac.uk',
            -port   => 4205,
            -user   => 'ensro',
            -pass   => '',
            -db_version => 73,
        },



	#'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
	'curr_core_sources_locs'    => [ $self->o('prod_loc1') ],
	'curr_core_dbs_locs'        => '', #if defining core dbs with config file. Define in Lastz_conf.pm or TBlat_conf.pm

	# executable locations:
	'exe_dir'=>'/nfs/panda/ensemblgenomes/production/compara/binaries/',
	'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",
	'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
	'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",
	'update_config_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/update_config_database.pl",
	'create_pair_aligner_page_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl",
	'faToNib_exe' => $self->o('exe_dir').'/faToNib',
	'lavToAxt_exe' => $self->o('exe_dir').'/lavToAxt',
	'axtChain_exe' => $self->o('exe_dir').'/axtChain',
	'chainNet_exe' => $self->o('exe_dir').'/chainNet',

	#Set for single pairwise mode
	'mlss_id' => '',

        #Collection name 
        'collection' => '',

	#Set to use pairwise configuration file
	'conf_file' => '',

	#Set to use registry configuration file
	'reg_conf' => '',

	#Reference species (if not using pairwise configuration file)
        'ref_species' => undef,

	#directory to dump nib files
	'dump_dir' => '/nfs/panda/ensemblgenomes/production/compara/' . $ENV{USER} . '/pair_aligner/nib_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

        #include MT chromosomes if set to 1 ie MT vs MT only else avoid any MT alignments if set to 0
        'include_MT' => 1,
	
	#include only MT, in some cases we only want to align MT chromosomes (set to 1 for MT only and 0 for normal mode). 
	#Also the name of the MT chromosome in the db must be the string "MT".    
	'MT_only' => 0, # if MT_only is set to 1, then include_MT must also be set to 1

	#min length to dump dna as nib file
	'dump_min_size' => 11500000, 

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
	'quick' => 1,

	#
	#Default chunking parameters
	#
         'default_chunks' => {#human example
			     'reference'   => {'chunk_size' => 30000000,
			    		       'overlap'    => 0,
			  		       'include_non_reference' => -1, #1  => include non_reference regions (eg human assembly patches)
					                                      #0  => do not include non_reference regions
					                                      #-1 => auto-detect (only include non_reference regions if the non-reference species is high-coverage 
					                                      #ie has chromosomes since these analyses are the only ones we keep up-to-date with the patches-pipeline)

#Human specific masking
#					       'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec"
                                              },
			     #non human example
#   			    'reference'     => {'chunk_size'      => 10000000,
#   						'overlap'         => 0,
#   						'masking_options' => '{default_soft_masking => 1}'},
   			    'non_reference' => {'chunk_size'      => 10100000,
   						'group_set_size'  => 10100000,
   						'overlap'         => 100000,
   						'masking_options' => '{default_soft_masking => 1}'},
   			    },
	    
	#Use transactions in pair_aligner and chaining/netting modules (eg LastZ.pm, PairAligner.pm, AlignmentProcessing.pm)
	'do_transactions' => 1,

        #
	#Default filter_duplicates
	#
        #'window_size' => 1000000,
        'window_size' => 10000,
	'filter_duplicates_rc_name' => '1Gb',
	'filter_duplicates_himem_rc_name' => 'crowd_himem',

	#
	#Default pair_aligner
	#
   	'pair_aligner_method_link' => [1001, 'LASTZ_RAW'],
	'pair_aligner_logic_name' => 'LastZ',
	'pair_aligner_program' => 'lastz',
	'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ',
	'pair_aligner_options' => 'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', #hsap vs mammal
	'pair_aligner_hive_capacity' => 100,
	'pair_aligner_batch_size' => 3,

        #
        #Default chain
        #
	'chain_input_method_link' => [1001, 'LASTZ_RAW'],
	'chain_output_method_link' => [1002, 'LASTZ_CHAIN'],

	 #linear_gap=>medium for more closely related species, 'loose' for more distant
	'linear_gap' => 'loose',

  	'chain_parameters' => {'max_gap'=>'50','linear_gap'=> $self->o('linear_gap'), 'faToNib' => $self->o('faToNib_exe'), 'lavToAxt'=> $self->o('lavToAxt_exe'), 'axtChain'=>$self->o('axtChain_exe')}, 
  	'chain_batch_size' => 5,
  	'chain_hive_capacity' => 50,

	#
        #Default patch_alignments
        #
	'patch_alignments' => 0,  #set to 1 to align the patches of a species to many other species

        #
        #Default net 
        #
	'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
        'net_output_method_link' => [16, 'LASTZ_NET'],
        'net_ref_species' => $self->o('ref_species'),  #default to ref_species
  	'net_parameters' => {'max_gap'=>'50', 'chainNet'=>$self->o('chainNet_exe')},
  	'net_batch_size' => 1,
  	'net_hive_capacity' => 20,
  	'bidirectional' => 1,

	#
	#Default healthcheck
	#
	'previous_db' => $self->o('livemirror_loc'),
	'prev_release' => 0,   # 0 is the default and it means "take current release number and subtract 1"    
	'max_percent_diff' => 20,
	'do_pairwise_gabs' => 1,
	'do_compare_to_previous_db' => 0,

        #
	#Default pairaligner config
	#
	'skip_pairaligner_stats' => 0, #skip this module if set to 1
#	'bed_dir' => '/nfs/ensembl/compara/dumps/bed/',
	'bed_dir' => '/nfs/panda/ensemblgenomes/production/compara/' . $ENV{USER} . '/pair_aligner/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',

	'output_dir' => '/nfs/panda/ensemblgenomes/production/compara' . $ENV{USER} . '/pair_aligner/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',
            
        #
        #Resource requirements
        #
        'memory_suffix' => "",                    #temporary fix to define the memory requirements in resource_classes
        'dbresource' => '',
	'aligner_capacity' => 2000,

    };
}

sub resource_classes {
    my ($self) = @_;

    return {
            #%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
	    'default' => {'LSF' => '-q production-rh6'},
            '100Mb' => { 'LSF' => '-q production-rh6 -M100' .' -R" rusage[mem=100]"' },
	    '500Mb' => { 'LSF' => '-q production-rh6 -M500' .' -R" rusage[mem=500]"' },
            '1Gb'   => { 'LSF' => '-q production-rh6 -M1000' .' -R" rusage[mem=1000]"' },
            'crowd' => { 'LSF' => '-q production-rh6 -M1800' .' -R" rusage[mem=1800]"' },
            'crowd_himem' => { 'LSF' => '-q production-rh6 -M3600' .' -R"rusage[mem=3600]"' },
	    '4.2Gb' => { 'LSF' => '-q production-rh6 -M4200' .' -R"rusage[mem=4200]"' },
	    '8.4Gb' => { 'LSF' => '-q production-rh6 -M8400' .' -R"rusage[mem=8400]"' },
    };
}


sub pipeline_analyses {
    my $self = shift;
    my $all_analyses = $self->SUPER::pipeline_analyses(@_);
    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$all_analyses;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'pairaligner_stats'         => 'crowd',
        'alignment_nets'            => 'crowd',
        'alignment_nets_himem'      => 'crowd_himem',
        'create_alignment_nets_jobs'=> 'crowd',
        'alignment_chains'          => '1Gb',
        'create_alignment_chains_jobs'  => 'crowd_himem',
        'dump_large_nib_for_chains_factory' => 'crowd',
        'create_filter_duplicates_jobs'     => 'crowd',
        'create_pair_aligner_jobs'  => 'crowd',
        'populate_new_database' => 'crowd',
        'parse_pair_aligner_conf' => '1Gb',
        'store_sequence'        => '1Gb',
        'store_sequence_again'  => 'crowd_himem',
        $self->o('pair_aligner_logic_name') => 'crowd_himem',
        $self->o('pair_aligner_logic_name')."_himem1" => '8.4Gb',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }

    # Other parameters that have to be set
    $analyses_by_name{'store_sequence_again'}->{'-hive_capacity'} = 50;

    return $all_analyses;
}


1;
