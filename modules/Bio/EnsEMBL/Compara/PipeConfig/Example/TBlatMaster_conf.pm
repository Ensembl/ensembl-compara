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

package Bio::EnsEMBL::Compara::PipeConfig::Example::TBlatMaster_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

	    #'master_db' => 'mysql://user@host/ensembl_compara_master',
	    'master_db' => 'mysql://ensro@ens-livemirror/ensembl_compara_68', #Use a release database for the test only.
	    'mlss_id'   => 421, #human vs chicken tblat-net

	    'livemirror_loc' => {
				 -host   => 'ens-livemirror',
				 -port   => 3306,
				 -user   => 'ensro',
				 -pass   => '',
				 -db_version => 68,
				},
	    
	    'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ], 

	    #Define location of core databases separately (over-ride curr_core_sources_locs in Pairwise_conf.pm)
#	    'reference' => {
#	    	-host           => "host_name",
#	    	-port           => port,
#	    	-user           => "user_name",
#	    	-dbname         => "my_human_database",
#	    	-species        => "homo_sapiens"
#	    },
#            'non_reference' => {
#	    	    -host           => "host_name",
#	    	    -port           => port,
#	    	    -user           => "user_name",
#	    	    -dbname         => "my_ciona_database",
#	    	    -species        => "ciona_intestinalis"
#	    	  },
#	    'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
#	    'curr_core_sources_locs'=> '',

	    'ref_species' => 'homo_sapiens',

	    #directory to dump dna files
	    'dump_dir' => '/lustre/scratch101/ensembl/' . $ENV{USER} . '/pair_aligner/dna_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

            # chr 22 vs chr 15
	    'default_chunks' => {
			     'reference'   => {'chunk_size' => 1000000,
				               'overlap'    => 10000,
					       'group_set_size' => 100000000,
					       'dump_dir' => $self->o('dump_dir'),
					       #human
					       'include_non_reference' => 1,
					       'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec",
					       'region' => 'chromosome:22',
					       #non-human
					       #'masking_options' => '{default_soft_masking => 1}',
					      },
   			    'non_reference' => {'chunk_size'      => 25000,
   						'group_set_size'  => 10000000,
   						'overlap'         => 10000,
   						'masking_options' => '{default_soft_masking => 1}',
                                                'region'          => 'chromosome:15',
					       },
   			    },

	    #Location of executables
	    'pair_aligner_exe' => '/software/ensembl/compara/bin/blat',

	   };
}

1;
