package Bio::EnsEMBL::Compara::PipeConfig::Example::LastzMasterConf_conf;

#
#Test with a master and pairwise alignment configuration file (lastz.conf)
#human chr 22 vs mouse chr 16 and human chr 22 vs rat chr 11
#Use lastz.conf to define the location of the core databases.
#Set the master to the ensembl release for this test only.
#

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    'pipeline_name'         => 'LASTZ_CONF_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
	    #'master_db' => 'mysql://user@host/ensembl_compara_master',
	    master_db => 'mysql://ensro@ens-livemirror:3306/ensembl_compara_68', #set to ensembl release for test only

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
