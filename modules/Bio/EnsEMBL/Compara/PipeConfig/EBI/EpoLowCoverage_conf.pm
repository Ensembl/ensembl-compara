=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 EXAMPLES

    # Without GERP (primates)
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EpoLowCoverage_conf $(mysql-ens-compara-prod-1-ensadmin details hive) -species_set_name primates -epo_db $(mysql-ens-compara-prod-1 details url muffato_primates_epo_94) -low_epo_mlss_id 1141 -high_epo_mlss_id 1134 -run_gerp 0 -ref_species homo_sapiens

    # With GERP (mammals, sauropsids, fish)
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EpoLowCoverage_conf $(mysql-ens-compara-prod-1-ensadmin details hive) -species_set_name fish -epo_db $(mysql-ens-compara-prod-3 details url carlac_fish_epo_94) -low_epo_mlss_id 1333 -high_epo_mlss_id 1332 -ref_species oryzias_latipes

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
    'division' => 'ensembl',
	'prev_release'  => '#expr( #ensembl_release# - 1 )expr#',

    #'host' => 'mysql-ens-compara-prod-4.ebi.ac.uk',
    #'port' => 4401,

    'work_dir' => '/hps/nobackup2/production/ensembl/' . join('/', $self->o('dbowner'), 'EPO_2X', $self->o('species_set_name') . '_' . $self->o('rel_with_suffix')),

    # place to get the genome dumps
    'genome_dumps_dir' => '/hps/nobackup2/production/ensembl/compara_ensembl/genome_dumps/'.$self->o('division'),
    'master_db' => 'compara_master',
	
    #default location for pairwise alignments (can be a string or an array-ref)
    'pairwise_location' => [ qw(compara_prev lastz_batch_1 lastz_batch_2 lastz_batch_3 lastz_batch_4 lastz_batch5 lastz_batch6 lastz_batch7 lastz_batch8 lastz_batch_9 lastz_batch_10) ],
    #'pairwise_location' => 'compara_curr',

	#Location of compara db containing the high coverage alignments
        #'epo_db' => 'compara_curr',
        'epo_db' => $self->o('species_set_name').'_epo', # registry name usually follows this convention for new EPO runs
	

    #ref species for pairwise alignments
 	# 'ref_species' => 'gallus_gallus',    # sauropsids 
	#'ref_species' => 'oryzias_latipes',  # fish
	# 'ref_species' => 'homo_sapiens',       # mammals

	 #gerp parameters
    'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.'.$self->o('division').'.branch_len.nw',     # location of full species tree, will be pruned
    };
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default' => { 'LSF' => ['', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
         '100Mb' => { 'LSF' => ['-C0 -M100  -R"select[mem>100]  rusage[mem=100]"', $reg_requirement] },
         '1Gb'   => { 'LSF' => ['-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"', $reg_requirement] },
	 	 '1.8Gb' => { 'LSF' => ['-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"', $reg_requirement] },
         '3.5Gb' => { 'LSF' => ['-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"', $reg_requirement] },
         '8Gb'   => { 'LSF' => ['-C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"', $reg_requirement] },
    };
}

1;
