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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::DumpAllForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::DumpAllForRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the DumpAllForRelease pipeline for the Vertebrates
division. Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::DumpAllForRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options },    # inherit the generic ones

        'dump_dir'         => $self->o('dump_root') . '/release-' . $self->o('ensembl_release'),
        'ancestral_db'     => 'ancestral_curr',

        'division'          => 'vertebrates',
        'epo_reference_species' => [ 'homo_sapiens', 'gallus_gallus', 'oryzias_latipes', 'sus_scrofa', 'mus_musculus' ],
    };
}

1;
