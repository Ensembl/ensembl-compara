package Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    'pipeline_name'         => 'LASTZ_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

	    #Define location of core databases separately (over-ride curr_core_sources_locs in Pairwise_conf.pm)
	    #'reference' => {
	    #	-host           => "host_name",
	    #	-port           => port,
	    #	-user           => "user_name",
	    #	-dbname         => "my_human_database",
	    #	-species        => "homo_sapiens"
	    #   },
            #'non_reference' => {
	    #	    -host           => "host_name",
	    #	    -port           => port,
	    #	    -user           => "user_name",
	    #	    -dbname         => "my_bushbaby_database",
	    #	    -species        => "otolemur_garnettii"
	    #	  },
	    
	    #'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
	    #'curr_core_sources_locs'=> '',

	    #Reference species
	    'ref_species' => 'homo_sapiens',

	    #Define chunking
	    'default_chunks' => {#human example
			     'reference'   => {'chunk_size' => 30000000,
					       'overlap'    => 0,
					       'include_non_reference' => 1,
#Should use this for human vs non-primate
					       'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec"},
			     #non human example
#   			    'reference'     => {'chunk_size'      => 10000000,
#   						'overlap'         => 0,
#   						'masking_options' => '{default_soft_masking => 1}'},
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
	    'pair_aligner_options' => 'T=1 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', #hsap vs mammal

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
