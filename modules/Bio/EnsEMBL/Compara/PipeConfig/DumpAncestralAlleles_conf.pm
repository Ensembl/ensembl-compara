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

Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=head1 DESCRIPTION

Pipeline for dumping ancestral alleles for the FTP.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'compara_db' => 'compara_curr',
        'ancestral_db' => 'ancestral_curr', # assume reg_conf is up-to-date

        'dump_dir'    => $self->o('pipeline_dir'),
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'ancestral_dump_program'  => $self->o('ancestral_dump_program'),
        'ancestral_stats_program' => $self->o('ancestral_stats_program'),

        'reg_conf'   => $self->o('reg_conf'),
        'compara_db' => $self->o('compara_db'),
        'ancestral_db' => $self->o('ancestral_db'),

        'dump_dir' => $self->o('dump_dir'),
        'anc_output_basedir' => "fasta/ancestral_alleles",
        'anc_output_dir'     => "#dump_dir#/#anc_output_basedir#",
        'anc_tmp_dir' => "#dump_dir#/tmp",

        'genome_dumps_dir' => $self->o('genome_dumps_dir'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles::pipeline_analyses_dump_anc_alleles($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ {} ];

    return $pipeline_analyses;
}

1;
