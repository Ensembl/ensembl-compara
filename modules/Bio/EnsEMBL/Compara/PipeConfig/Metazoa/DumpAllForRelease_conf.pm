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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::DumpAllForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::DumpAllForRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the DumpAllForRelease pipeline for the Metazoa
division. Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::DumpAllForRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options },    # inherit the generic ones

        # List of mlss_ids that we have re_ran/updated and cannot be detected through first_release
        # 'updated_mlss_ids' => [ 9802, 9803, 9804, 9805, 9806 ],

        'dump_dir'         => $self->o('dump_root') . '/release-' . $self->o('eg_release'),

        'division'         => 'metazoa',

        'prev_rel_ftp_root' => $self->o('ftp_root') . '/release-' . $self->o('prev_eg_release') . '/' . $self->o('division'),
    };
}

1;
