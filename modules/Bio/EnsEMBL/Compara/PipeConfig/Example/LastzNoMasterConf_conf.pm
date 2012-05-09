package Bio::EnsEMBL::Compara::PipeConfig::Example::LastzNoMasterConf_conf;

#
#Test with no master and pairwise alignment configuration file (lastz.conf)
#human chr 22 vs mouse chr 16 and human chr 22 vs rat chr 11
#Use lastz.conf to define the location of the core databases.
#

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    'pipeline_name'         => 'LASTZ_CONF_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
	    master_db => '', #Must undefine master_db

	    #Location of executables
	    'pair_aligner_exe' => '/software/ensembl/compara/bin/lastz',

	    #
	    #Skip pairaligner stats module
	    #
	    'skip_pairaligner_stats' => 1,
	    'bed_dir' => $self->o('dump_dir').'/bed_files', 
	    'output_dir' => $self->o('dump_dir').'/output', 
	   };
}

1;
