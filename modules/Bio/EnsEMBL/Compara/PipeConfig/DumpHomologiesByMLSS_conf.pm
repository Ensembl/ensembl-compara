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

Bio::EnsEMBL::Compara::PipeConfig::DumpHomologiesByMLSS_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpHomologiesByMLSS_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -member_type ncrna

=head1 DESCRIPTION

This pipeline dumps all the gene-trees and homologies under #base_dir#.

By default the pipeline dumps the database named "compara_curr" in the
registry, but a different database can be selected with --rel_db.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::DumpHomologiesByMLSS_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');   # we don't need Compara tables in this particular case

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.

=cut

sub default_options {
    my ($self) = @_;
    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'compara_db'  => 'compara_ptrees',
        'member_type' => 'protein',

        'dump_hom_capacity'   => 10,    # how many homologies can be dumped in parallel
        
        'homology_dumps_dir' => $self->o('pipeline_dir'),
    };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'homology_dumps_dir' => $self->o('homology_dumps_dir'),
        'division'           => $self->o('division'),
        'compara_db'         => $self->o('compara_db'),
        'reg_conf'           => $self->o('reg_conf'),
        'member_type'        => $self->o('member_type'),
        'dump_hom_capacity'  => $self->o('dump_hom_capacity' ),
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    my $pa = Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpHomologiesForPosttree::pipeline_analyses_dump_homologies_posttree($self);
    $pa->[0]->{'-input_ids'} = [{}];
    return $pa;
}

1;
