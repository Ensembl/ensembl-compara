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

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf;

#
#Test with a master and method_link_species_set_id.
#human chr 22 and mouse chr 16
#Use 'curr_core_sources_locs' to define the location of the core databases.
#Set the master to the ensembl release for this test only.

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    #'pipeline_name'         => 'lastz_ebi_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'host'      => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port'      =>  4522,
	    'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master',


	    'staging_loc' => {
            -host   => 'mysql-ens-sta-1.ebi.ac.uk',
            -port   => 4519,
            -user   => 'ensro',
            -pass   => '',
        },

	    'livemirror_loc' => {
			-host   => 'mysql-ensembl-mirror.ebi.ac.uk',
			-port   => 4240,
			-user   => 'anonymous',
			-pass   => '',
			-db_version => $self->o('rel_with_suffix'),
		},
	    
	    'curr_core_sources_locs' => [ $self->o('staging_loc') ], 
	    # 'curr_core_sources_locs' => [ $self->o('livemirror_loc') ], 

	    #Location of executables
	    'pair_aligner_exe' => $self->o('ensembl_cellar').'/lastz/1.02.00/bin/lastz',

	    #
	    #Default pair_aligner
	    #
	    'pair_aligner_method_link' => [1001, 'LASTZ_RAW'],
	    'pair_aligner_logic_name' => 'LastZ',
	    'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ',

	    #
	    #Default chain
	    #
	    'chain_input_method_link' => [1001, 'LASTZ_RAW'],
	    'chain_output_method_link' => [1002, 'LASTZ_CHAIN'],

	    #
	    #Default net 
	    #
	    'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
	    'net_output_method_link' => [16, 'LASTZ_NET'],


	    'dump_dir' => '/hps/nobackup/production/ensembl/' . $ENV{USER} . '/pair_aligner/release_' . $self->o('rel_with_suffix') . '/',
	    'bed_dir' => $self->o('dump_dir').'/bed_dir', 
	    'output_dir' => $self->o('dump_dir').'/feature_dumps',

	    'faToNib_exe'  => $self->o('ensembl_cellar').'/kent/v335/bin/faToNib',
        'lavToAxt_exe' => $self->o('ensembl_cellar').'/kent/v335/bin/lavToAxt',
        'axtChain_exe' => $self->o('ensembl_cellar').'/kent/v335/bin/axtChain',
        'chainNet_exe' => $self->o('ensembl_cellar').'/kent/v335/bin/chainNet',

	   };
}

sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb'       => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'         => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'long'        => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'crowd'       => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
            'crowd_himem' => { 'LSF' => '-C0 -M6000 -R"select[mem>6000] rusage[mem=6000]"' },
    };
}

1;
