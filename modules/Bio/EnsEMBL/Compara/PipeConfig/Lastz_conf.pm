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

Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf

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
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf --dbname hsap_btau_lastz_64 --password <your password> --mlss_id 534 --pipeline_db -host=compara1 --ref_species homo_sapiens --pipeline_name LASTZ_hs_bt_64 

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

package Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

	    #Define location of core databases separately (over-ride curr_core_sources_locs in Pairwise_conf.pm)
	    'reference' => {
	    	-host           => "ens-livemirror",
	    	-port           => 3306,
	    	-user           => "ensro",
	    	-dbname         => "mus_musculus_core_78_38",
	    	-species        => "mus_musculus"
	       },
            'non_reference' => {
	    	    -host           => "compara1",
	    	    -port           => 3306,
	    	    -user           => "ensro",
	    	    -dbname         => "mm14_db8_rat6_ref",
	    	    -species        => "rattus_norvegicus"
	    	  },
	    
	    'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
	    'curr_core_sources_locs'=> '',

	    #Reference species
	    'ref_species' => 'mus_musculus',

	    #Define chunking
	    'default_chunks' => {#human example
			     #'reference'   => {'chunk_size' => 30000000,
			#		       'overlap'    => 0,
			#		       'include_non_reference' => -1, #1  => include non_reference regions (eg human assembly patches)
					                                      #0  => do not include non_reference regions
					                                      #-1 => auto-detect (only include non_reference regions if the non-reference species is high-coverage 
					                                      #ie has chromosomes since these analyses are the only ones we keep up-to-date with the patches-pipeline)

#Should use this for human vs non-primate
			#		       'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec"},
			     #non human example
   			    'reference'     => {'chunk_size'      => 10000000,
   						'overlap'         => 0,
   						'masking_options' => '{default_soft_masking => 1}'},
   			    'non_reference' => {'chunk_size'      => 10100000,
   						'group_set_size'  => 10100000,
   						'overlap'         => 100000,
   						'masking_options' => '{default_soft_masking => 1}'},
   			    },

	    #Location of executables
	    'pair_aligner_exe' => '/software/ensembl/compara/bin/lastz',

	    #
	    #Default pair_aligner
	    #
	    'pair_aligner_method_link' => [1001, 'LASTZ_RAW'],
	    'pair_aligner_logic_name' => 'LastZ',
	    'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ',
	    'pair_aligner_options' => 'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', #hsap vs mammal

	    #
	    #Default chain
	    #
	    'chain_input_method_link' => [1001, 'LASTZ_RAW'],
	    'chain_output_method_link' => [1002, 'LASTZ_CHAIN'],
	    'linear_gap' => 'medium',

	    #
	    #Default net 
	    #
	    'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
	    'net_output_method_link' => [16, 'LASTZ_NET'],
	   };
}

1;
