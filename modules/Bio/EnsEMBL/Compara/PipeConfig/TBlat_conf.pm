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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #4. Check all default_options below, especially
        ref_species (if not homo_sapiens)
        default_chunks
        pair_aligner_options

    #5. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf -host mysql-ens-compara-prod-X -port XXXX \
            -division vertebrates -ref_species danio_rerio -mlss_id 574

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

This configuration file gives defaults specific for the translated blat net pipeline.
It inherits from PairAligner_conf.pm and parameters here will over-ride the parameters in PairAligner_conf.pm.
Please see PairAligner_conf.pm for general details of the pipeline.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

        # We connect to the databases via the Registry configuration file of the division
        'master_db'              => 'compara_master',
        'curr_core_sources_locs' => undef,
        'curr_core_dbs_locs'     => undef,

        # Work directory
        'dump_dir' => $self->o('pipeline_dir'),

        # TBlat is used to align the genomes
        'pair_aligner_exe' => $self->o('blat_exe'),

            'default_chunks' => {
                'reference'   => {'chunk_size' => 1000000,
                    'overlap'    => 10000,
                    'group_set_size' => 100000000,
                    'dump_dir' => $self->o('dump_dir'),
                    #human
                    'include_non_reference' => 0, #Do not use non_reference regions (eg human assembly patches) since these will not be kept up-to-date
                    'masking'         => 'soft',
                },
                'non_reference' => {'chunk_size'      => 25000,
                    'group_set_size'  => 10000000,
                    'overlap'         => 10000,
                    'masking'         => 'soft',
                },
            },

	    #Default pair_aligner
	    'pair_aligner_method_link' => [1001, 'TRANSLATED_BLAT_RAW'],
	    'pair_aligner_logic_name' => 'Blat',
	    'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::Blat',
	    'pair_aligner_options' => '-minScore=30 -t=dnax -q=dnax -mask=lower -qMask=lower',

	    #Default chain
	    'chain_input_method_link' => [1001, 'TRANSLATED_BLAT_RAW'],
	    'chain_output_method_link' => [1002, 'TRANSLATED_BLAT_CHAIN'],
	    'linear_gap' => 'loose',

	    #Default net 
	    'net_input_method_link' => [1002, 'TRANSLATED_BLAT_CHAIN'],
	    'net_output_method_link' => [7, 'TRANSLATED_BLAT_NET'],

        # Capacities
        'pair_aligner_analysis_capacity'  => 100,
        'pair_aligner_batch_size'         => 3,
        'chain_hive_capacity'             => 50,
        'chain_batch_size'                => 5,
        'net_hive_capacity'               => 20,
        'net_batch_size'                  => 1,
        'filter_duplicates_hive_capacity' => 200,
        'filter_duplicates_batch_size'    => 10,
	   };
}


1;
