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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MercatorPecan_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MercatorPecan_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

    The Vertebrates PipeConfig file for MercatorPecan pipeline that should
    automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MercatorPecan_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
        'species_set_name'      => 'amniotes',
        'division'              => 'vertebrates',
        'do_not_reuse_list'     => [ ],

    # previous release data location for reuse
    'reuse_db'  => 'amniotes_pecan_prev',   # Cannot be the release db because we need exon members and the peptide_align_feature tables
    };
}


1;

