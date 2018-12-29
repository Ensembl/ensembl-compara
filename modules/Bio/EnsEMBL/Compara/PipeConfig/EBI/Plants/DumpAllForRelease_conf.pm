
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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf

=head1 DESCRIPTION

The PipeConfig file for the pipeline that performs FTP dumps of everything required for a
given release. It will detect which pipelines have been run and dump anything new.

Example: init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::DumpAllForRelease_conf -host mysql-ens-compara-prod-5 -port 4615 -pipeline_name dump_plants_release_95 -division plants

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::DumpAllForRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options },    # inherit the generic ones

        # Location of the previous dumps
        'prev_ftp_dump' => '/nfs/production/panda/ensemblgenomes/ftp/pub/release-41/plants/',

        ##the list of mlss_ids that we have re_ran/updated and cannot be detected through first_release
        #'updated_mlss_ids' => [ 9802, 9803, 9804, 9805, 9806, 9807, 9788, 9789, 9810, 9794, 9809, 9748, 9749, 9750, 9751, 9763, 9764, 9765,
        #                        9766, 9778, 9779, 9780, 9781, 9797, 9798, 9799, 9800, 9801, 9808, 9787, 9813, 9814, 9812 ],

        'dump_root'        => '/hps/nobackup2/production/ensembl/' . $ENV{'USER'} . '/release_dumps_' . $self->o('division') . '_42',
        'pipeline_name'    => 'dump_all_for_release_42',
        'dump_dir'         => '#dump_root#/release-42',
        'ancestral_db'     => undef,

        'division'          => 'plants',
    };
}

1;
