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

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EpoLowCoverage_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        #'species_set_name'  => 'primates',

	'rel_suffix'	=> $self->o('species_set_name') . '_' . $self->o('ensembl_release'),
	'ensembl_release' => 92,
	'prev_release'  => '#expr( #ensembl_release# - 1 )expr#',

    'host' => 'mysql-ens-compara-prod-4.ebi.ac.uk',
    'port' => 4401,

    'work_dir' => '/hps/nobackup/production/ensembl/' . $ENV{USER} . '/EPO_2X/' . 'release_' . $self->o('rel_with_suffix') . '/',

    'pipeline_db' => {
        -host   => $self->o('host'),
        -port   => $self->o('port'),
        -user   => 'ensadmin',
        -pass   => $self->o('password'),
        -dbname => $ENV{USER}.'_EPO_low_'.$self->o('rel_suffix'),
        -driver => 'mysql',
    },

	#Location of compara db containing most pairwise mlss ie previous compara
	'live_compara_db' => {
        -host   => 'mysql-ens-compara-prod-1',
        -port   => 4485,
        -user   => 'ensro',
        -pass   => '',
		-dbname => 'ensembl_compara_' . $self->o('ensembl_release'),
		-driver => 'mysql',
    },

    #location of new pairwise mlss if not in the pairwise_default_location eg:
    'pairwise_exception_location' => { },
	# 'pairwise_exception_location' => {
    #      1024 => 'mysql://ensro@mysql-ens-compara-prod-3:4523/ensembl_compara_rodents_89',
	# },

	#Location of compara db containing the high coverage alignments
	'epo_db' => 'mysql://ensro@mysql-ens-compara-prod-3.ebi.ac.uk:4523/carlac_fish_epo_92',

	'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',

	'staging_loc1' => {
        -host   => 'mysql-ens-vertannot-staging',
        -port   => 4573,
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

    #ref species for pairwise alignments
 	# 'ref_species' => 'gallus_gallus',    # sauropsids 
	'ref_species' => 'oryzias_latipes',  # fish
	# 'ref_species' => 'homo_sapiens',       # mammals

	'pairwise_default_location' => $self->dbconn_2_url('live_compara_db'), #default location for pairwise alignments

	 #gerp parameters
	'gerp_version' => '2.1',                            #gerp program version
	'no_gerp_conservation_scores' => 0,                 #Not used in productions but is a valid argument
        'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.ensembl.branch_len.nw',     # location of full species tree, will be pruned
    'species_to_skip' => undef,

	#Location of executables (or paths to executables)
    'gerp_exe_dir'    => $self->check_dir_in_cellar('gerp/20080211_1/bin'),   #gerp program
    'semphy_exe'      => $self->check_exe_in_cellar('semphy/2.0b3/bin/semphy'), #semphy program
    'treebest_exe'    => $self->check_exe_in_cellar('treebest/88/bin/treebest'), #treebest program

    # stats report email
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
         '3.5Gb' =>  { 'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
    };
}

1;
