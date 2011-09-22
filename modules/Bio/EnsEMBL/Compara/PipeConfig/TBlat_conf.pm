package Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    'pipeline_name'         => 'TBLAT_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

	    #directory to dump dna files
	    'dump_dna_dir' => '/lustre/scratch101/ensembl/' . $ENV{USER} . '/pair_aligner/dna_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

	    'default_chunks' => {
			     'reference'   => {'chunk_size' => 1000000,
				               'overlap'    => 10000,
					       'group_set_size' => 100000000,
#					       'include_non_reference' => 1,
#					       'masking_options_file' => '/nfs/users/nfs_k/kb3/work/hive/data/human36.spec'
					       'masking_options' => '{default_soft_masking => 1}',
#					       'dump_loc' => '/lustre/scratch101/ensembl/kb3/scratch/hive/tests/test_pairaligner_conf/chicken',
					       'dump_dir' => $self->o('dump_dna_dir'),
					      },
   			    'non_reference' => {'chunk_size'      => 25000,
   						'group_set_size'  => 10000000,
   						'overlap'         => 10000,
   						'masking_options' => '{default_soft_masking => 1}'
					       },
   			    },

	    #Location of executables
	    'pair_aligner_exe' => '/usr/local/ensembl/bin/blat-32',

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

	    #
	    #Default net 
	    #
	    'net_input_method_link' => [1002, 'TRANSLATED_BLAT_CHAIN'],
	    'net_output_method_link' => [7, 'TRANSLATED_BLAT_NET'],

	   };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
       'mkdir -p '.$self->o('dump_dna_dir'), #Make dump_dna_dir directory
    ];
}

1;
