=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::PipeConfig::EBI_EpoLowCoverage_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones



	'rel_suffix'	=> '11way_fish_89',
	'ensembl_release' => 89, 
	'prev_release'  => 88,
    'host' => 'mysql-ens-compara-prod-3.ebi.ac.uk',
    'pipeline_db' => {
        -host   => $self->o('host'),
        -port   => 4523,
        -user   => 'ensadmin',
        -pass   => $self->o('password'),
        -dbname => $ENV{USER}.'_EPO_low_'.$self->o('rel_suffix'),
    -driver => 'mysql',
    },

	#Location of compara db containing most pairwise mlss ie previous compara
	'live_compara_db' => {
        -host   => 'mysql-ensembl-mirror.ebi.ac.uk',
        -port   => 4240,
        -user   => 'anonymous',
        -pass   => '',
		-dbname => 'ensembl_compara_88',
		-driver => 'mysql',
    },

    #location of new pairwise mlss if not in the pairwise_default_location eg:
	#'pairwise_exception_location' => { },
	'pairwise_exception_location' => { 795 => 'mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_88', #T.rub-O.lat
									   }, #O.lat-M.mus

	#Location of compara db containing the high coverage alignments
	'epo_db' => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/sf5_epo_5fish_79',

	master_db => { 
            -host   => 'mysql-ens-compara-prod-1.ebi.ac.uk',
            -port   => 4485,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'ensembl_compara_master',
	    -driver => 'mysql',
        },
	'populate_new_database_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",

	'staging_loc1' => {
            -host   => 'mysql-ens-sta-1',
            -port   => 4519,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('ensembl_release'),
        },

	'livemirror_loc' => {
            -host   => 'mysql-ensembl-mirror.ebi.ac.uk',
            -port   => 4240,
            -user   => 'anonymous',
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

	'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment
	'high_epo_mlss_id' => $self->o('high_epo_mlss_id'), #mlss_id for high coverage epo alignment
	'ce_mlss_id' => $self->o('ce_mlss_id'),             #mlss_id for low coverage constrained elements
	'cs_mlss_id' => $self->o('cs_mlss_id'),             #mlss_id for low coverage conservation scores
#	'ref_species' => 'gallus_gallus',                    #ref species for pairwise alignments
	'ref_species' => 'oryzias_latipes',
#	'ref_species' => 'homo_sapiens',
	'max_block_size'  => 1000000,                       #max size of alignment before splitting 
	'pairwise_default_location' => $self->dbconn_2_url('live_compara_db'), #default location for pairwise alignments

        'step' => 10000, #size used in ImportAlignment for selecting how many entries to copy at once

	 #gerp parameters
	'gerp_version' => '2.1',                            #gerp program version
	'gerp_window_sizes'    => '[1,10,100,500]',         #gerp window sizes
	'no_gerp_conservation_scores' => 0,                 #Not used in productions but is a valid argument
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.11fish.branch_len.nw', #location of full species tree, will be pruned 
	'work_dir' => $self->o('work_dir'),                 #location to put pruned tree file 
        'species_to_skip' => undef,

	#Location of executables (or paths to executables)
	'gerp_exe_dir'    => $self->o('ensembl_cellar').'/gerp/20080211/bin',   #gerp program
        'semphy_exe'      => $self->o('ensembl_cellar').'/semphy/2.0b3/bin/semphy', #semphy program
        'treebest_exe'      => $self->o('ensembl_cellar').'/treebest/88/bin/treebest', #treebest program
        'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

        #
        #Default statistics
        #
        'skip_multiplealigner_stats' => 0, #skip this module if set to 1
        'bed_dir' => '/hps/nobackup/production/ensembl/' . $ENV{USER} . '/EPO_Lc_test/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',
        'output_dir' => '/hps/nobackup/production/ensembl/' . $ENV{USER} . '/EPO_Lc_test/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',

        #
        #Resource requirements

       # stats report email
       'epo_stats_report_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/production/epo_stats.pl",
  	   'epo_stats_report_email' => $ENV{'USER'} . '@ebi.ac.uk',
    };
}

sub resource_classes {
    my ($self) = @_;

    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
         '1Gb'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
	 	 '1.8Gb' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
    };
}

1;
