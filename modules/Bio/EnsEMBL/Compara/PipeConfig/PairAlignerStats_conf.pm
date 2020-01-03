=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf

=head1 DESCRIPTION

Pipeline that computes and stores statistics for a pairwise alignment.

Note: This is usually embedded in all the pairwise-alignment pipelines, but
is also available as a standalone pipeline in case the stats have to be
rerun or the alignment has been imported

=head1 SYNOPSIS

This pipeline requires two arguments: a compara database (to read the alignment
and store the stats) and a mlss_id.

The first analysis ("pairaligner_stats") can be re-seeded with extra parameters to
compute stats on other alignments.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

example : init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf -compara_db <> -mlss_id <> -host <> -port <> --reg_conf

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Dump location
        'dump_dir'      => $self->o('pipeline_dir'),
        'bed_dir'       => $self->o('dump_dir').'bed_dir',
        'output_dir'    => $self->o('dump_dir').'output_dir',
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        #Store CodingExon coverage statistics
        $self->db_cmd('CREATE TABLE IF NOT EXISTS statistics (
        method_link_species_set_id  int(10) unsigned NOT NULL,
        genome_db_id                int(10) unsigned NOT NULL,
        dnafrag_id                  bigint unsigned NOT NULL,
        matches                     INT(10) DEFAULT 0,
        mis_matches                 INT(10) DEFAULT 0,
        ref_insertions              INT(10) DEFAULT 0,
        non_ref_insertions          INT(10) DEFAULT 0,
        uncovered                   INT(10) DEFAULT 0,
        coding_exon_length          INT(10) DEFAULT 0,
        PRIMARY KEY (method_link_species_set_id,dnafrag_id)
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;'),

        $self->pipeline_create_commands_rm_mkdir(['output_dir', 'bed_dir']),
    ];
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},       # here we inherit anything from the base class
        'compara_db'    => $self->o('compara_db'),
    }
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'pairaligner_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
            -parameters => {
                'dump_features'             => $self->o('dump_features_exe'),
                'compare_beds'              => $self->o('compare_beds_exe'),
                'create_pair_aligner_page'  => $self->o('create_pair_aligner_page_exe'),
                'bed_dir'                   => $self->o('bed_dir'),
                'ensembl_release'           => $self->o('ensembl_release'),
                'output_dir'                => $self->o('output_dir'),
            },
            -input_ids  => [
                {
                    'mlss_id'       => $self->o('mlss_id'),
                }
            ],
            -flow_into  => {
                'A->1' => [ 'coding_exon_stats_summary' ],
                '2->A' => [ 'coding_exon_stats' ],
            },
            -rc_name    => '1Gb_job',
        },
        {   -logic_name => 'coding_exon_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats',
            -rc_name    => '1Gb_job',
            -analysis_capacity  => 100,
        },
        {   -logic_name => 'coding_exon_stats_summary',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary',
            -rc_name    => '1Gb_job',
        },
    ];
}

1;
