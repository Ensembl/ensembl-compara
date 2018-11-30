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

Initialise the pipeline on compara1 and dump the constrained elements of mlss_id 836
found at cc21_ensembl_compara_86 on compara5

  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf -compara_url mysql://ensro@compara5/cc21_ensembl_compara_86 -mlss_id 836 -host compara1 -registry $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl

Dumps are created in a sub-directory of --export_dir, which defaults to scratch109

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpConstrainedElements_conf;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Paths to compara files
        'dump_features_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'ce_readme'             => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/docs/ftp/constrained_elements.txt",
        'bigbed_autosql'        => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/constrainedelements_autosql.as",
    };
}


# Ensures species output parameter gets propagated implicitly
sub hive_meta_table {
    my ($self) = @_;

    return {
        %{$self->SUPER::hive_meta_table},
        'hive_use_param_stack'  => 1,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'dump_features_program' => $self->o('dump_features_program'),
        'ce_readme'             => $self->o('ce_readme'),

        'registry'      => $self->o('registry'),
        'compara_db'   => $self->o('compara_url'),

        'export_dir'    => $self->o('export_dir'),
        'ce_output_dir'    => '#export_dir#/bed/ensembl-compara/#dirname#',
        'bed_file'   => '#ce_output_dir#/gerp_constrained_elements.#name#.bed',
        'bigbed_file'   => '#ce_output_dir#/gerp_constrained_elements.#name#.bb',
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    
    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements::pipeline_analyses_dump_constrained_elems($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [ { mlss_id => $self->o('mlss_id') } ];

    return $pipeline_analyses;
}

1;
