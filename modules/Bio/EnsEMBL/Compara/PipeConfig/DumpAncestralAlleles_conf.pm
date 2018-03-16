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


=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'reg_conf' => undef,
        'curr_release' => $ENV{CURR_ENSEMBL_RELEASE},

        'compara_db' => 'compara_curr',
        'reg_conf'   => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl",
    	'dump_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl",
    	'stats_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/ancestral_sequences/get_stats.pl",

    	'export_dir'    => '/hps/nobackup/production/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix'),
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'dump_program'  => $self->o('dump_program'),
        'stats_program' => $self->o('stats_program'),

        'reg_conf'   => $self->o('reg_conf'),
        'compara_db' => $self->o('compara_db'),
        'export_dir' => $self->o('export_dir'),
        'output_dir' => "#export_dir#/fasta/ancestral_alleles",
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [

    	{	-logic_name => 'mk_dump_dir',
    		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
    		-parameters => {
    			cmd => 'mkdir -p #output_dir#'
    		},
    		-input_ids  => [ {} ],
    		-flow_into => ['fetch_genome_dbs'],
    		# -flow_into => {
      #           '2->A' => [ 'fetch_genome_dbs' ],
      #           'A->1' => [ 'md5sum' ],
      #       },
    	},

        {   -logic_name     => 'fetch_genome_dbs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpAncestralAlleles::GenomeDBFactory',
            -parameters     => {
                compara_db => $self->o('compara_db'),
                reg_conf   => $self->o('reg_conf'),
            },
            # -flow_into  => [ 'get_ancestral_sequence' ],
            -flow_into => {
            	'2->A' => [ 'get_ancestral_sequence' ],
            	'A->1' => [ 'md5sum' ],
            }
        },

        {	-logic_name => 'get_ancestral_sequence',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        	-parameters => {
        		species_outdir => '#output_dir#/#species_dir#',
        		cmd => join('; ', 
        			'perl #dump_program# --conf #reg_conf# --species #species_name# --dir #species_outdir# --alignment_db compara_curr --ancestral_db ancestral_curr',
        			'cd #species_outdir#',
        			'perl #stats_program# > summary.txt',
        			),
        	},
        	-flow_into => [ 'tar' ],
        	-analysis_capacity => 2,
        },

        {	-logic_name => 'tar',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        	-parameters => {
        		cmd => join( '; ',
        			'cd #output_dir#',
        			'tar cfvz #species_dir#.tar.gz #species_dir#/'
        		)
        	}
        },

        {	-logic_name => 'md5sum',
        	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
        	-parameters => {
        		cmd => join( '; ',
        			'cd #output_dir#',
        			'md5sum *.tar.gz > MD5SUM'
        		)
        	}
        }
    ];
}

1;
