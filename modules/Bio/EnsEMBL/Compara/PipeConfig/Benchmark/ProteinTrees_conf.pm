=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Benchmark::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Benchmark::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The PipeConfig file for ProteinTrees pipeline on the benchmark set (e98 - 200 genomes)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Benchmark::ProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'    => 'benchmark',
        'mlss_id'     => 40133,

        'prev_rel_db' => undef, # turn off reuse
    };
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'backbone_fire_db_prepare'}->{'-parameters'}->{'manual_ok'} = '1';
}

1;
