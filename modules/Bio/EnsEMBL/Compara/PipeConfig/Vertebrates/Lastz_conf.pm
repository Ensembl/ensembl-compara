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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::Lastz_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::Lastz_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id_list "[1596,1583,1570,1562]"

=head1 DESCRIPTION

This is a Vertebrates configuration file for LastZ pipeline. Please, refer
to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::Lastz_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');


sub default_options {
    my ($self) = @_;
    return {
	    %{$self->SUPER::default_options},   # inherit the generic ones

        'division'  => 'vertebrates',
	};
}


1;
