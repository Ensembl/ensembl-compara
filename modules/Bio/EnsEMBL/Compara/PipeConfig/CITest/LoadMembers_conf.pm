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

=head1 NAME

Bio::Bio::EnsEMBL::Compara::PipeConfig::CITest::LoadMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CITest::LoadMembers_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

This is a CITest configuration file for LoadMembers pipeline. Please, refer to the
parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CITest::LoadMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'   => 'citest',
        'collection' => 'citest',

        # Names of species we don't want to reuse this time
        #'do_not_reuse_list' => [ 'homo_sapiens', 'mus_musculus', 'rattus_norvegicus', 'mus_spretus_spreteij', 'danio_rerio', 'sus_scrofa' ],
        'do_not_reuse_list' => [ ],

        # Load non reference sequences and patches for fresh members
        'include_nonreference' => 0,
        'include_patches'      => 0,

        # Run the pipeline without reuse
        'reuse_member_db' => undef,
    };
}


1;
