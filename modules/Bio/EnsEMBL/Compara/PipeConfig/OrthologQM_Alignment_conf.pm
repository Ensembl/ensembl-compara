=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf;

=head1 DESCRIPTION

	http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs

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
			homology_id           varchar(255) NOT NULL,
            genomic_aln_block_id  varchar(255) NOT NULL,
            genome_db_id          INT NOT NULL,
            exon_coverage         FLOAT(5,2) NOT NULL,
            intron_coverage       FLOAT(5,2) NOT NULL 
        )'),
		$self->db_cmd( 'CREATE TABLE ortholog_quality_summary (
			homology_id              varchar(255) NOT NULL,
            genome_db_id             INT NOT NULL,
            combined_exon_coverage   FLOAT(5,2) NOT NULL,
            combined_intron_coverage FLOAT(5,2) NOT NULL,
			quality_score            INT NOT NULL 
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
        'default'      => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
        '2Gb_job'      => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '20Gb_job'      => {'LSF' => '-C0 -M20000  -R"select[mem>20000]  rusage[mem=20000]"' },
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
                1 => [ 'prepare_orthologs' ],
            },
        },

        {   -logic_name => 'prepare_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs',
            -analysis_capacity  =>  10,  # use per-analysis limiter
            -flow_into => {
                '2->A' => [ 'prepare_pairwise_aln' ],
                'A->1' => [ 'assign_quality'  ],
            },
            -rc_name => '2Gb_job',
            -parameters => { 'compara_db' => 'mysql://ensro@ens-livemirror/ensembl_compara_82' },
            #-input_ids => [{}],
        },

        {   -logic_name => 'prepare_pairwise_aln',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment',
            -analysis_capacity => 100,
            -flow_into  => {
                '2->A' => [ 'ortholog_vs_alignment' ],
                'A->1' => [ 'combine_coverage'  ],
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'ortholog_vs_alignment',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Alignment_v_Ortholog',
            -analysis_capacity  =>  100,  # use per-analysis limiter
            -flow_into => {
                1 => [ ':////accu?orth_exon_ranges={orth_id}' ],
                2 => [ ':////ortholog_quality' ],
            },
        },

        {   -logic_name => 'combine_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage',
            -flow_into  => {
                '1'  => [ ':////ortholog_quality_summary' ],
                '-1' => [ 'combine_coverage_himem' ],
            },

        },

        {   -logic_name => 'combine_coverage_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage',
            -flow_into  => {
                1 => [ ':////ortholog_quality_summary' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'assign_quality', # formerly calculate_threshold
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore',
        },

    ];
}

1;