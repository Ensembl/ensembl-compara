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

Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Check all default_options in PairAligner_conf.pm, especically:
        release
        pipeline_db (-host)
        resource_classes 

    #4. Check all default_options below, especially
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options

    #5. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf --dbname drer_onil_tblat_67 --password <your password> --mlss_id 574 --pipeline_db -host=compara1 --ref_species danio_rerio --pipeline_name TBLAT_dr_on_67

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    This configuaration file gives defaults specific for the translated blat net pipeline. It inherits from PairAligner_conf.pm and parameters here will over-ride the parameters in PairAligner_conf.pm. 
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

            'default_chunks' => {
                'reference'   => {'chunk_size' => 1000000,
                    'overlap'    => 10000,
                    'group_set_size' => 100000000,
                    'dump_dir' => $self->o('dump_dir'),
                    #human
                    'include_non_reference' => 0, #Do not use non_reference regions (eg human assembly patches) since these will not be kept up-to-date
                    #'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec",
                    #non-human
                    'masking_options' => '{default_soft_masking => 1}',
                },
                'non_reference' => {'chunk_size'      => 25000,
                    'group_set_size'  => 10000000,
                    'overlap'         => 10000,
                    'masking_options' => '{default_soft_masking => 1}'
                },
            },

	    #
	    #Default pair_aligner
	    #
	    'pair_aligner_method_link' => [1001, 'TRANSLATED_BLAT_RAW'],
	    'pair_aligner_logic_name' => 'Blat',
	    'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::Blat',
	    'pair_aligner_options' => '-minScore=30 -t=dnax -q=dnax -mask=lower -qMask=lower',

	    #
	    #Default chain
	    #
	    'chain_input_method_link' => [1001, 'TRANSLATED_BLAT_RAW'],
	    'chain_output_method_link' => [1002, 'TRANSLATED_BLAT_CHAIN'],
	    'linear_gap' => 'loose',

	    #
	    #Default net 
	    #
	    'net_input_method_link' => [1002, 'TRANSLATED_BLAT_CHAIN'],
	    'net_output_method_link' => [7, 'TRANSLATED_BLAT_NET'],

	   };
}


1;
