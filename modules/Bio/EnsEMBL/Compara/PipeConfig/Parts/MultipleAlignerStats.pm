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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats

=head1 DESCRIPTION

Set of analyses to compute statistics on a multiple-alignment database.
It is supposed to be embedded in pipelines.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN
 
sub pipeline_analyses_multiple_aligner_stats {
    my ($self) = @_;
    return [
        {   -logic_name => 'multiplealigner_stats_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'skip_multiplealigner_stats'    => $self->o('skip_multiplealigner_stats'),
            },
            -flow_into  => {
                '2->A' => WHEN( 'not #skip_multiplealigner_stats#' => [ 'multiplealigner_stats' ] ),
                'A->1' => [ 'block_size_distribution' ],
                    1  => ['gab_stats_semaphore_holder'],
            },
        },

        {   -logic_name => 'multiplealigner_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
            -parameters => {
                'dump_features'     => $self->o('dump_features_exe'),
                'compare_beds'      => $self->o('compare_beds_exe'),
                'bed_dir'           => $self->o('bed_dir'),
                'ensembl_release'   => $self->o('ensembl_release'),
                'output_dir'        => $self->o('output_dir'),
            },
            -rc_name => '3.5Gb',
            -hive_capacity  => 100,
        },

        {   -logic_name => 'block_size_distribution',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerBlockSize',
            -flow_into  => [ 'email_stats_report' ],
        },

        {   -logic_name => 'email_stats_report',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::EmailStatsReport',
            -parameters => {
                'stats_exe' => $self->o('epo_stats_report_exe'),
                'email'     => $self->o('epo_stats_report_email'),
            }
        },

        {   -logic_name => 'gab_stats_semaphore_holder',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => ['Genomic_Align_Block_Job_Generator'],
                'A->1' => ['backbone_summary_job_generator']
                },
        },

        {   -logic_name => 'Genomic_Align_Block_Job_Generator',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'mlss_id'  => $self->o('mlss_id'),
                            'contiguous'  => 0,
                            'inputquery'  => 'SELECT DISTINCT genomic_align_block_id FROM genomic_align WHERE method_link_species_set_id = #mlss_id# AND dnafrag_id < 10000000000',
                        },
            -flow_into  => {
                2 => ['alignment_depth_calculator','pw_aligned_base_calculator'],
                },
        },

        {   -logic_name =>  'alignment_depth_calculator',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::AlignmentDepthCalculator',
            -flow_into  => {
                2 => [ '?accu_name=aligned_positions_counter&accu_address={genome_db_id}[]&accu_input_variable=num_of_aligned_positions' ],
                3 => [ '?accu_name=aligned_sequences_counter&accu_address={genome_db_id}[]&accu_input_variable=sum_aligned_seq'],
            },
        },

        {   -logic_name =>  'pw_aligned_base_calculator',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculatePwAlignedBases',
            -flow_into  => {
                2 => [ '?accu_name=aligned_bases_counter&accu_address={frm_genome_db_id}{to_genome_db_id}[]&accu_input_variable=no_of_aligned_bases' ]
            },
        },

        {   -logic_name => 'backbone_summary_job_generator',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MWGAStatsSummarizer',
            -flow_into  =>  {
                2 => 'compute_genome_alignment_depth',
                3 => 'compute_genomes_pw_aligned_bases',
                },
        },

        {   -logic_name => 'compute_genome_alignment_depth',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::DetermineGenomeAlignmentDepth',
        },

        {   -logic_name => 'compute_genomes_pw_aligned_bases',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::DetermineGenomePwAlignedBases',
        },

    ];
}

1;
