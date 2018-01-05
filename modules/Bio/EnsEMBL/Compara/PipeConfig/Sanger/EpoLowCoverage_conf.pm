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

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::EpoLowCoverage_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf');

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

	'rel_suffix'	=> 86,
	'ensembl_release' => 86, 
	'prev_release'  => 85,
    'host' => 'compara4',
        
    'work_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/EPO_Lc/' . 'release_' . $self->o('rel_with_suffix') . '/',

    'pipeline_db' => {
        -host   => $self->o('host'),
        -port   => 3306,
        -user   => 'ensadmin',
        -pass   => $self->o('password'),
        -dbname => $ENV{USER}.'_EPO_low_'.$self->o('rel_suffix'),
    -driver => 'mysql',
    },

	#Location of compara db containing most pairwise mlss ie previous compara
	'live_compara_db' => {
        -host   => 'compara5',
        -port   => 3306,
        -user   => 'ensro',
        -pass   => '',
		-dbname => 'wa2_ensembl_compara_85',
		-driver => 'mysql',
    },

    #location of new pairwise mlss if not in the pairwise_default_location eg:
	#'pairwise_exception_location' => { },
	'pairwise_exception_location' => { 820 => 'mysql://ensro@compara3/cc21_hsap_mmul_mmur_lastz_86', 
									   821 => 'mysql://ensro@compara3/cc21_hsap_mmul_mmur_lastz_86',},

	#Location of compara db containing the high coverage alignments
	'epo_db' => 'mysql://ensro@compara3:3306/cc21_mammals_epo_pt3_86',

	master_db => { 
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -dbname => 'mm14_ensembl_compara_master',
	    -driver => 'mysql',
        },

	'staging_loc1' => {
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('ensembl_release'),
        },
        'staging_loc2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('ensembl_release'),
        },  
	'livemirror_loc' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('prev_release'),
        },

		'additional_core_db_urls' => { },

		#If we declare things like this, it will FAIL!
		#We should include the locator on the master_db
		#'additional_core_db_urls' => {
			#-host => 'compara1',
			#-user => 'ensro',
			#-port => 3306,
            #-pass   => '',
			#-species => 'rattus_norvegicus',
			#-group => 'core',
			#-dbname => 'mm14_db8_rat6_ref',
	    	#-db_version => 76,
		#},

#	'ref_species' => 'gallus_gallus',                    #ref species for pairwise alignments
#	'ref_species' => 'oryzias_latipes',
	'ref_species' => 'homo_sapiens',

	'pairwise_default_location' => $self->dbconn_2_url('live_compara_db'), #default location for pairwise alignments

	 #gerp parameters
	'gerp_version' => '2.1',                            #gerp program version
	'no_gerp_conservation_scores' => 0,                 #Not used in productions but is a valid argument
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.39mammals.branch_len.nw', #location of full species tree, will be pruned 
        'species_to_skip' => undef,

	#Location of executables (or paths to executables)
	'gerp_exe_dir'    => '/software/ensembl/compara/gerp/GERPv2.1',   #gerp program
        'semphy_exe'      => '/software/ensembl/compara/semphy_latest', #semphy program
        'treebest_exe'      => '/software/ensembl/compara/treebest.doubletracking', #treebest program

        #
        #Resource requirements
        #
       'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
       'aligner_capacity' => 2000,

       # stats report email
  	   'epo_stats_report_email' => $ENV{'USER'} . '@sanger.ac.uk',
    };
}


sub resource_classes {
    my ($self) = @_;

    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
         '1Gb'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1000,'.$self->o('dbresource').'=10:duration=3]"' },
	 '1.8Gb' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
    };
}


1;
