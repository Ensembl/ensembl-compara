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

Bio::EnsEMBL::Compara::PipeConfig::Plants::WheatLastz_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::WheatLastz_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id_list "[9821]"


=head1 DESCRIPTION

This is a Plants configuration file for LastZ pipeline of wheat genomes.
Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::WheatLastz_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Plants::Lastz_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # Decrease these capacities
        'chain_hive_capacity'   => 20,
        'net_hive_capacity'     => 100,
    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $self->SUPER::tweak_analyses($analyses_by_name);

    # Increase the memory for chaining
    my %overriden_rc_names = (
        'alignment_chains'          => '8Gb_job',
        'alignment_chains_himem'    => '16Gb_job',
        'alignment_chains_hugemem'  => '32Gb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
}


1;
