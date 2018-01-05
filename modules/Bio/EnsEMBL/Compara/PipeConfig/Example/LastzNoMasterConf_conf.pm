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
