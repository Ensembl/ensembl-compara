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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -compara_db compara_curr

=head1 DESCRIPTION  

Pipeline to dump all the species-trees from the the given compara database.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpSpeciesTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        #Locations to write output files
        'dump_dir'          => $self->o('pipeline_dir'),
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        'dump_dir'      => $self->o('dump_dir'),
        'compara_db'    => $self->o('compara_db'),
        'reg_conf'      => $self->o('reg_conf'),
        'dump_species_tree_exe' => $self->o('dump_species_tree_exe'),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my $pipeline_analyses = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees::pipeline_analyses_dump_species_trees($self);
    $pipeline_analyses->[0]->{'-input_ids'} = [{}];

    return $pipeline_analyses;
}

1;
