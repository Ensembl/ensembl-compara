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

package Bio::EnsEMBL::Compara::PipeConfig::Example::LastzNoMaster_conf;

#
#Test with no master and method_link_species_set_id.
#human chr 22 and mouse chr 16
#Define core databases using 'curr_core_dbs_locs'.
#

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones
	    'pipeline_name'         => 'LASTZ_NOMASTER_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
          'master_db' => '', #Set master as an empty string

	    #Must define location of core dbs if no master
 	    'reference' => {
 		       -host           => "ens-livemirror",
 		       -port           => 3306,
 		       -user           => "ensro",
 		       -dbname         => "homo_sapiens_core_73_37",
		       -species        => "homo_sapiens"
 		      },
 	    'non_reference' => {
 		       '-host'           => "ens-livemirror",
 		       '-port'           => 3306,
 		       '-user'           => "ensro",
 		       '-dbname'         => "mus_musculus_core_73_38",
 		       '-species'        => "mus_musculus"
 		      },
	    'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
	    'curr_core_sources_locs'=> '', #Must undefine or else will try to load from PairAligner_conf

	    'ref_species' => 'homo_sapiens',

	    'default_chunks' => {#human example
			     'reference'   => {'chunk_size' => 30000000,
					       'overlap'    => 0,
					       'include_non_reference' => 1,
					       'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec",
					       'region' => 'chromosome:22'},
   			    'non_reference' => {'chunk_size'      => 10100000,
   						'group_set_size'  => 10100000,
   						'overlap'         => 100000,
   						'masking_options' => '{default_soft_masking => 1}',
					        'region'          => 'chromosome:16'},
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

	    #
	    #Default net 
	    #
	    'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
	    'net_output_method_link' => [16, 'LASTZ_NET'],

	    #
	    #Skip pairaligner stats module
	    #
	    'skip_pairaligner_stats' => 1,
	    'bed_dir' => $self->o('dump_dir').'/bed_files', 
	    'output_dir' => $self->o('dump_dir').'/output', 
	   };
}

1;
