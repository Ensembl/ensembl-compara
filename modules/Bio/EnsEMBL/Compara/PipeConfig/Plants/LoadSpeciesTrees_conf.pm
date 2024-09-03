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

Bio::EnsEMBL::Compara::PipeConfig::Plants::LoadSpeciesTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::LoadSpeciesTrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The Plpants configuration of the LoadSpeciesTrees pipeline. Please, refer to
the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::LoadSpeciesTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadSpeciesTrees_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'              => 'plants',
        'compara_alias_name'    => 'compara_curr',
        'species_tree'          => $self->o('config_dir') . '/species_tree.topology.nw',

        'binary'    => 0,  # The tree shared by Plants is not binary
        'n_missing_species_in_tree' => 0,
    };
}


1;
