=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

=head1 SYNOPSIS

Pipeline to dump conservation scores as bedGraph and bigWig files

    $ init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpConservationScores_conf -compara_url $(mysql-ens-compara-prod-4 details url mateus_epo_low_68_way_mammals_92) -mlss_id 1136 -registry '' $(mysql-ens-compara-prod-2-ensadmin details hive)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::DumpConservationScores_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpConservationScores_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Where dumps are created
        'export_dir'    => '/hps/nobackup/production/ensembl/'.$ENV{'USER'}.'/dumps_'.$self->o('rel_with_suffix').'/cs',

        # How many species can be dumped in parallel
        'capacity'    => 50,

        # executable locations:
        'big_wig_exe'   => $self->check_exe_in_cellar('kent/v335_1/bin/bedGraphToBigWig'),
    };
}


sub resource_classes {
    my ($self) = @_;

    my $reg_options = $self->o('registry') ? '--reg_conf '.$self->o('registry') : '';
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'crowd' => { 'LSF' => '-C0 -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
    };
}

1;
