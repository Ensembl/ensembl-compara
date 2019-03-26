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

Pipeline to dump conservation scores as bedGraph and bigWig files

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpConservationScores_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConservationScores;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Paths to compara files
        'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'cs_readme'             => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/docs/ftp/conservation_scores.txt",
    };
}


sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'dump_features_exe'     => $self->o('dump_features_exe'),
        'cs_readme'             => $self->o('cs_readme'),
        'dump_cs_capacity'      => 100,

        'registry'      => $self->o('registry'),
        'compara_db'    => $self->o('compara_url'),

        'work_dir'      => $self->o('work_dir'),
        'chromsize_file'=> '#work_dir#/gerp_conservation_scores.#name#.chromsize',
        'bedgraph_file' => '#work_dir#/gerp_conservation_scores.#name#.bedgraph',

        'export_dir'    => $self->o('export_dir'),

        'cs_output_dir' => '#export_dir#/compara/conservation_scores/#dirname#',
        'bigwig_file'   => '#cs_output_dir#/gerp_conservation_scores.#name#.#assembly#.bw',
    };
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub pipeline_analyses {
    my ($self) = @_;
    
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConservationScores::pipeline_analyses_dump_conservation_scores($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ { mlss_id => $self->o('mlss_id') } ];

    return $pipeline_analyses;
}

1;
