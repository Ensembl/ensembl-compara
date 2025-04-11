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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstQuery

=head1 DESCRIPTION

For the purpose of reciprocal DIAMOND BLAST, this partial config expects reference genomes
preloaded in batched FASTA files and query genomes loaded into the pipeline. A DIAMOND db
is generated for each of the query genomes in pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstQuery;

use strict;
use warnings;

use File::Spec::Functions;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

sub pipeline_analyses_diamond_against_query {
    my ($self) = @_;

    my %blastp_parameters = (
        'diamond_exe'   => $self->o('diamond_exe'),
        'blast_params'  => $self->o('blast_params'),
        'evalue_limit'  => $self->o('evalue_limit'),
    );

    return [
        {   -logic_name    => 'make_query_blast_db',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::MakeDiamondDBPerGenomeDB',
            -rc_name       => '16Gb_24_hour_job',
            -priority      => 1,
            -flow_into     => {
                1 => { 'ref_from_fasta_factory' => INPUT_PLUS() },
            },
        },

        {   -logic_name    => 'ref_from_fasta_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::RefFromFastaFactory',
            -parameters    => {
                'get_genebuild_id_exe' => $self->o('get_genebuild_id_exe'),
                'ref_reg_conf'         => catfile($self->o('ensembl_root_dir'), 'ensembl-compara', 'conf', 'references', 'production_reg_conf.pl'),
            },
            -priority      => 1,
            -flow_into     => {
                '2' => { 'diamond_blastp_ref_to_query'  => INPUT_PLUS() },
            },
        },

        {   -logic_name    => 'diamond_blastp_ref_to_query',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondFromFilePAF',
            -parameters    => {
                %blastp_parameters,
            },
            -rc_name       => '2Gb_4c_24_hour_job',
            -flow_into     => {
               -1 => [ 'diamond_blastp_ref_to_query_himem' ],  # MEMLIMIT
            },
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name    => 'diamond_blastp_ref_to_query_himem',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondFromFilePAF',
            -parameters    => {
                %blastp_parameters,
            },
            -rc_name       => '4Gb_4c_24_hour_job',
            -priority      => 20,
            -hive_capacity => $self->o('blastpu_capacity'),
        },

    ];
}

1;
