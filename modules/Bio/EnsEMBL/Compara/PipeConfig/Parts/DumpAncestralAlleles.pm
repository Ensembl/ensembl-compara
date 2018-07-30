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

=head1 SYNOPSIS
 
 Pipeline analyses for dumping ancestral alleles for the FTP.

See Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf for more information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

sub pipeline_analyses_dump_anc_alleles {
    my ($self) = @_;
    return [

    	{	-logic_name => 'mk_ancestral_dump_dir',
    		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
    		-parameters => {
                    cmd => 'mkdir -p #anc_output_dir# #anc_tmp_dir#'
    		},
    		# -input_ids  => [ {} ],
    		-flow_into => ['fetch_genome_dbs'],
    	},

        {   -logic_name     => 'fetch_genome_dbs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpAncestralAlleles::GenomeDBFactory',
            -parameters     => {
                compara_db => $self->o('compara_db'),
                reg_conf   => $self->o('reg_conf'),
            },
            -flow_into => {
            	'2->A' => [ 'get_ancestral_sequence' ],
            	'A->1' => [ 'md5sum' ],
            }
        },

        {	-logic_name => 'get_ancestral_sequence',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        	-parameters => {
                        species_outdir => '#anc_tmp_dir#/#species_dir#',
        		cmd => join('; ', 
        			'perl #ancestral_dump_program# --conf #reg_conf# --species #species_name# --dir #species_outdir# --alignment_db #compara_db# --ancestral_db #ancestral_db#',
        			'cd #species_outdir#',
                    'find . -empty -type f -delete',
                                'perl #ancestral_stats_program# > summary.txt',
        			),
        	},
        	-flow_into => [ 'tar' ],
        	-hive_capacity => 400,
        },

        {	-logic_name => 'tar',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        	-parameters => {
        		cmd => join( '; ',
                                    'cd #anc_tmp_dir#',
                                    'tar cfvz #anc_output_dir#/#species_dir#.tar.gz #species_dir#/'
        		)
        	}
        },

        {	-logic_name => 'md5sum',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        	-parameters => {
        		cmd => join( '; ',
        			'cd #anc_output_dir#',
        			'md5sum *.tar.gz > MD5SUM'
        		)
        	}
        }
    ];
}

1;
