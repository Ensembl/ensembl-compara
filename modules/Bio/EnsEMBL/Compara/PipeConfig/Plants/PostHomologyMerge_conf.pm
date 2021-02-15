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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Plants::PostHomologyMerge_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::PostHomologyMerge_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specific version of PostHomologyMerge for Plants.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Plants::PostHomologyMerge_conf;

use strict;
use warnings;


use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS


use base ('Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'        => 'plants',

        'do_member_stats_fam'   => 0,
    };
}




1;
