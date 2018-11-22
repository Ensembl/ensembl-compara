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

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Lastz_conf;


use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Work directory
        'dump_dir' => '/hps/nobackup2/production/ensembl/' . $ENV{USER} . '/pair_aligner/release_' . $self->o('rel_with_suffix') . '/lastz_'.$self->o('pipeline_name') . '/' . $self->o('host') . '/',

        # Capacities
        'pair_aligner_analysis_capacity' => 700,
        'pair_aligner_batch_size' => 40,
        'chain_hive_capacity' => 200,
        'chain_batch_size' => 10,
        'net_hive_capacity' => 300,
        'net_batch_size' => 10,
        'filter_duplicates_hive_capacity' => 200,
        'filter_duplicates_batch_size' => 10,

        #Location of executables
        'pair_aligner_exe'  => $self->check_exe_in_cellar('lastz/1.04.00/bin/lastz'),
        'faToNib_exe'       => $self->check_exe_in_cellar('kent/v335_1/bin/faToNib'),
        'lavToAxt_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/lavToAxt'),
        'axtChain_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/axtChain'),
        'chainNet_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/chainNet'),

    };
}

sub resource_classes {
    my ($self) = @_;

    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb_job'       => { 'LSF' => ['-C0 -M100 -R"select[mem>100] rusage[mem=100]"]', $reg_requirement] },
            '1Gb_job'         => { 'LSF' => ['-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"', $reg_requirement] },
            '1.8Gb_job'       => { 'LSF' => ['-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"', $reg_requirement] },
            '8Gb_job'         => { 'LSF' => ['-C0 -M8000 -R"select[mem>8000] rusage[mem=8000]"', $reg_requirement] },
            '10Gb_job'        => { 'LSF' => ['-C0 -M10000 -R"select[mem>10000] rusage[mem=10000]"', $reg_requirement] },
    };
}

1;
