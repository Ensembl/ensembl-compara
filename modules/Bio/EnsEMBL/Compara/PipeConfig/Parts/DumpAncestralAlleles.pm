=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles

=head1 DESCRIPTION

This PipeConfig contains the core analyses required to dump the ancestral
alleles.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  # Allow this particular config to use conditional dataflow and INPUT_PLUS

sub pipeline_analyses_dump_anc_alleles {
    my ($self) = @_;
    return [

    	{	-logic_name => 'mk_ancestral_dump_dir',
    		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
    		-parameters => {
                    cmd => 'mkdir -p #anc_output_dir# #anc_tmp_dir#'
    		},
    		# -input_ids  => [ {} ],
    		-flow_into => ['fetch_genome_dbs'],
    	},

        {   -logic_name     => 'fetch_genome_dbs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpAncestralAlleles::GenomeDBFactory',
            -rc_name        => '1Gb_job',
            -parameters     => {
                compara_db => $self->o('compara_db'),
                reg_conf   => $self->o('reg_conf'),
            },
            -flow_into => {
            	'2->A' => [ 'get_ancestral_sequence' ],
                'A->1' => [ 'anc_funnel_check' ],
            }
        },

        {   -logic_name => 'anc_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'md5sum' => INPUT_PLUS() } ],
        },

        {   -logic_name => 'get_ancestral_sequence',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                species_outdir  => '#anc_tmp_dir#/#species_dir#',
                step_size       => 20_000_000,
                cmd             => join( ' ',
                    'perl #ancestral_dump_program#',
                    '--conf #reg_conf#',
                    '--species #species_name#',
                    '--dir #species_outdir#',
                    '--alignment_db #compara_db#',
                    '--ancestral_db #ancestral_db#',
                    '--genome_dumps_dir #genome_dumps_dir#',
                    '--step #step_size#'
                ),
            },
            -rc_name            => '2Gb_24_hour_job',
            -flow_into => [ 'remove_empty_files' ],
            -hive_capacity => 400,
        },

        {   -logic_name => 'remove_empty_files',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                species_outdir  => '#anc_tmp_dir#/#species_dir#',
                cmd             => 'find #species_outdir# -empty -type f -delete',
            },
            -flow_into => [ 'generate_anc_stats' ],
        },

        {   -logic_name => 'generate_anc_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                species_outdir  => '#anc_tmp_dir#/#species_dir#',
                cmd             => 'cd #species_outdir#; perl #ancestral_stats_program# > summary.txt',
            },
            -flow_into => [ 'tar' ],
        },

        {	-logic_name => 'tar',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
        	-parameters => {
        		cmd => join( '; ',
                                    'cd #anc_tmp_dir#',
                                    'tar cfvz #anc_output_dir#/#species_dir#.tar.gz #species_dir#/'
        		)
        	}
        },

        {	-logic_name => 'md5sum',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
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
