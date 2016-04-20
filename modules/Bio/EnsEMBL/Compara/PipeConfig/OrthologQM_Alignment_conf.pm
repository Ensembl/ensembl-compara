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

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf

    To run on a collection:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -collection <species_set_name>
        or
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -species_set_id <species_set dbID>

    To run on a pair of species:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -species1 homo_sapiens -species2 gallus_gallus

=head1 DESCRIPTION

    This pipeline uses whole genome alignments to calculate the coverage of homologous pairs.
    The coverage is calculated on both exonic and intronic regions seperately and summarised using a quality_score calculation
    The average quality_score between both members of the homology will be written to the homology table (in compara_db option)

    http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs

    Additional options:
    -compara_db         database containing relevant data. NOTE: this is where final scores will be written
    -alt_aln_db         take alignment objects from a different source
    -alt_homology_db    take homology objects from a different source


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

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'compara_db'      => "mysql://ensadmin:$ENV{EHIVE_PASS}\@compara5/cc21_ensembl_compara_84",
        'species1'        => undef,
        'species2'        => undef,
        'collection'      => undef,
        'species_set_id'  => undef,
        'ref_species'     => undef,
        'reg_conf'        => "$ENV{'ENSEMBL_CVS_ROOT_DIR'}/scripts/pipeline/production_reg_conf.pl",
        'alt_aln_db'      => undef,
        'alt_homology_db' => undef,
        'user'            => 'ensadmin',        
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
            -input_ids => [{
                'collection'      => $self->o('collection'),
                'species_set_id'  => $self->o('species_set_id'),
                'ref_species'     => $self->o('ref_species'),
                'compara_db'      => $self->o('compara_db'),
                'species1'        => $self->o('species1'),
                'species2'        => $self->o('species2'),
                'compara_db'      => $self->o('compara_db'),
                'alt_aln_db'      => $self->o('alt_aln_db'),
                'alt_homology_db' => $self->o('alt_homology_db'),
            }],
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
            #-input_ids => {},
        },

        {   -logic_name        => 'prepare_exons',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons',
            -analysis_capacity => 100,
            -flow_into         => {
                1 => [ 'prepare_pairwise_aln' ],
            },
            -rc_name => 'default_with_reg_conf',
            #-input_ids => {}
        },

        {   -logic_name => 'prepare_pairwise_aln',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment',
            -analysis_capacity => 100,
            -flow_into  => {
                1 => [ 'combine_coverage'  ],
            },
            -rc_name => '2Gb_job',
            #-input_ids => {},
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