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

Bio::EnsEMBL::Compara::PipeConfig::Plants::LoadMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::LoadMembers_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the LoadMembers pipeline for Plants. Please, refer
to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::LoadMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'    => 'plants',

    # names of species we don't want to reuse this time
        #'do_not_reuse_list' => [ 'oryza_indica', 'vitis_vinifera' ],
        'do_not_reuse_list' => [ ],

    # "Member" parameters:
        # Store ncRNA genes
        'store_ncrna'               => 0,
        # Store other genes
        'store_others'              => 0,
    };
}


1;

