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

Bio::EnsEMBL::Compara::PipeConfig::EBI::TBlat_conf

=head1 DESCRIPTION

Version of the TBlat pipeline to run on the EBI infrastructure

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::TBlat_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::TBlat_conf');     # We are running TBlat


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Work directory
        'dump_dir' => '/hps/nobackup2/production/ensembl/' . $ENV{USER} . '/pair_aligner/release_' . $self->o('rel_with_suffix') . '/tblat_'.$self->o('pipeline_name') . '/' . $self->o('host') . '/',

        #Location of executables
        'pair_aligner_exe'  => $self->check_exe_in_cellar('kent/v335_1/bin/blat'),
        'faToNib_exe'       => $self->check_exe_in_cellar('kent/v335_1/bin/faToNib'),
        'lavToAxt_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/lavToAxt'),
        'axtChain_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/axtChain'),
        'chainNet_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/chainNet'),

    };
}


sub resource_classes {
    my ($self) = @_;

    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        '100Mb_job' => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
        '500Mb_job' => { 'LSF' => '-C0 -M500 -R"select[mem>500] rusage[mem=500]"' },
        '1Gb_job'   => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
        '1.8Gb_job' => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
        '3.6Gb_job' => { 'LSF' => '-C0 -M3600 -R"select[mem>3600] rusage[mem=3600]"' },
        '4.2Gb_job' => { 'LSF' => '-C0 -M4200 -R"select[mem>4200] rusage[mem=4200]"' },
        '8Gb_job'   => { 'LSF' => '-C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"' },
        '8.4Gb_job' => { 'LSF' => '-C0 -M8400 -R"select[mem>8400] rusage[mem=8400]"' },
        '10Gb_job'  => { 'LSF' => '-C0 -M10000 -R"select[mem>10000] rusage[mem=10000]"' },
    };
}


1;
