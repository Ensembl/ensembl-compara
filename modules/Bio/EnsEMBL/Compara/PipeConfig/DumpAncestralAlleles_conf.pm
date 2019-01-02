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

=head1 SYNOPSIS
 
 Pipeline for dumping ancestral alleles for the FTP.

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf 

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpAncestralAlleles_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpAncestralAlleles;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'compara_db' => 'compara_curr',
        'ancestral_db' => 'ancestral_curr', # assume reg_conf is up-to-date

        'reg_conf'   => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_ebi_conf.pl",
    	'ancestral_dump_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl",
    	'ancestral_stats_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/ancestral_sequences/get_stats.pl",

        'genome_dumps_dir'    => '/hps/nobackup2/production/ensembl/compara_ensembl/genome_dumps/', # Where we can find the genome dumps to speed up fetching sequences

        # 'export_dir'    => '/hps/nobackup2/production/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix'),
    	'dump_dir'    => '/hps/nobackup2/production/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix'),
    };
}

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
        'anc_output_dir' => "#dump_dir#/fasta/ancestral_alleles",
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
