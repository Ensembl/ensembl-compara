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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Sanger::Lastz_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. Check all default_options below, especially
        release
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options

    #5. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Sanger::Lastz_conf --dbname hsap_btau_lastz_64 --password <your password> --mlss_id 534 --pipeline_db -host=compara1 --ref_species homo_sapiens --pipeline_name LASTZ_hs_bt_64 

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    This configuaration file gives defaults specific for the lastz net pipeline. It inherits from PairAligner_conf.pm and parameters here will over-ride the parameters in PairAligner_conf.pm. 
    Please see PairAligner_conf.pm for general details of the pipeline.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::Lastz_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

	    #Define location of core databases separately (over-ride curr_core_sources_locs in Pairwise_conf.pm)
	    'reference' => {
	    	-host           => "compara4",
	    	-port           => 3306,
	    	-user           => "ensro",
	    	-dbname         => "cc21_CAROLI_EiJ_core_80",
	    	-species        => "mus_caroli"
	       },
            'non_reference' => {
	    	    -host           => "compara4",
	    	    -port           => 3306,
	    	    -user           => "ensro",
	    	    -dbname         => "wa2_Pahari_EiJ_core_80",
	    	    -species        => "mus_pahari"
	    	  },
	    
	    #if collection is set both 'curr_core_dbs_locs' and 'curr_core_sources_locs' parameters are set to undef otherwise the are to use the default pairwise values
	    $self->o('collection') ? 
	    	('curr_core_dbs_locs'=>undef, 
	    		'curr_core_sources_locs'=> undef) : 
	    	('curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ], 
	    		'curr_core_sources_locs'=> ''),

	    #Reference species
	    'ref_species' => 'mus_caroli',

	    #Location of executables
	    'pair_aligner_exe' => '/software/ensembl/compara/bin/lastz',

            # Capacities
            'filter_duplicates_hive_capacity' => 200,
            'filter_duplicates_batch_size' => 10,
            'pair_aligner_analysis_capacity' => 700,
            'pair_aligner_batch_size' => 40,
            'chain_hive_capacity' => 200,
            'chain_batch_size' => 10,
            'net_hive_capacity' => 300,
            'net_batch_size' => 10,

        #
        #Resource requirements
        #
        'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
        'aligner_capacity' => 2000,
    }
}


sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'long'   => { 'LSF' => '-q long -C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'crowd' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1800,'.$self->o('dbresource').'=10:duration=3]"' },
            'crowd_himem' => { 'LSF' => '-C0 -M6000 -R"select[mem>6000 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=6000,'.$self->o('dbresource').'=10:duration=3]"' },
    };
}


1;
