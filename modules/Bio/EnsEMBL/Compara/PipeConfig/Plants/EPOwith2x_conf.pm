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

Bio::EnsEMBL::Compara::PipeConfig::Plants::EPOwith2x_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::EPOwith2x_conf.pm -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -species_set_name <species_set_name> -low_epo_mlss_id <id> -high_epo_mlss_id <id>

=head1 DESCRIPTION

    This pipeline runs EPO and EPO2x together. For more information on each pipeline, see their respective PipeConfig files:
    - Bio::EnsEMBL::Compara::PipeConfig::EPO_conf
    - Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::EPOwith2x_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPOwith2x_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'enredo_params'     => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 2000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',
        'division'          => 'plants',
        'reuse_db'          => undef,
        'binary_species_tree'   => $self->o('config_dir').'/species_tree.'.$self->o('species_set_name').'.branch_len.nw',
    };
}

1;
