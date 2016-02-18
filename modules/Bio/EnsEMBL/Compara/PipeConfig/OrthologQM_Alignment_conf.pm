=pod

=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME
	
	Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf;

=head1 DESCRIPTION

	http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf;

use strict;
use warnings;

use base ( 'Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf' );

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

=head2 pipeline_create_commands 
	
	Description: create tables for writing data to

=cut

sub pipeline_create_commands {
	my $self = shift;

	#!!! NOTE: replace column names with desired col names for report.
	#          must be a param name!

	#PRIMARY KEY (genomic_align_block_id))'

	return [
		@{ $self->SUPER::pipeline_create_commands },
		$self->db_cmd( 'CREATE TABLE ortholog_quality (
			homology_id              INT NOT NULL,
            genome_db_id             INT NOT NULL,
            combined_exon_coverage   FLOAT(5,2) NOT NULL,
            combined_intron_coverage FLOAT(5,2) NOT NULL,
			quality_score            FLOAT(5,2) NOT NULL,
            exon_length              INT NOT NULL,
            intron_length            INT NOT NULL
        )'),
        $self->db_cmd( 'CREATE TABLE ortholog_quality_tags (
            quality_score  INT NOT NULL,
            description    varchar(255) NOT NULL
        )'),
	];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'take_time'     => 1,
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'default'               => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
        'default_with_reg_conf' => {'LSF' => ['-C0 -M100   -R"select[mem>100]   rusage[mem=100]"', '--reg_conf '.$self->o('reg_conf')] },
        '2Gb_job'               => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '20Gb_job'              => {'LSF' => '-C0 -M20000  -R"select[mem>20000]  rusage[mem=20000]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'pair_species',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection',
            -flow_into  => {
                2 => [ 'select_mlss' ],
            },
        },

        {   -logic_name => 'select_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS',
            -flow_into  => {
                1 => [ 'write_threshold' ],
                2 => [ 'prepare_orthologs' ], 
            },
        },

        {   -logic_name => 'prepare_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs',
            -analysis_capacity  =>  10,  # use per-analysis limiter
            -flow_into => {
                2 => [ 'prepare_exons' ],
                #'A->1' => [ 'assign_quality'  ],
            },
            -rc_name => '2Gb_job',
            #-parameters => { 'compara_db' => 'mysql://ensro@ens-livemirror/ensembl_compara_82' },
            #-input_ids => [{}],
        },

        {   -logic_name        => 'prepare_exons',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons',
            -analysis_capacity => 100,
            -flow_into         => {
                1 => [ 'prepare_pairwise_aln' ],
            },
            -rc_name => 'default_with_reg_conf'
        },

        {   -logic_name => 'prepare_pairwise_aln',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment',
            -analysis_capacity => 100,
            -flow_into  => {
                1 => [ 'combine_coverage'  ],
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'combine_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage',
            -flow_into  => {
                '1'  => [ ':////ortholog_quality' ],
                '2'  => [ 'assign_quality' ],
                '-1' => [ 'combine_coverage_himem' ],
            },

        },

        {   -logic_name => 'combine_coverage_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage',
            -flow_into  => {
                1 => [ ':////ortholog_quality' ],
                2 => [ 'assign_quality' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'assign_quality',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore',
        },

        {   -logic_name => 'write_threshold',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WriteThreshold'

        },

    ];
}

1;