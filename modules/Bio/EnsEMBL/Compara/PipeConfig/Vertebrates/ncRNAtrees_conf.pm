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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

This is the Vertebrates PipeConfig for the ncRNAtrees pipeline. Please, refer
to the parent class for further information.

=head1 EXAMPLES

e104
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf $(mysql-ens-compara-prod-3-ensadmin details hive)

e99
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf -mlss_id 40139 $(mysql-ens-compara-prod-7-ensadmin details hive)

e96
    # All the databases are defined in the production_reg_conf so the command-line is much simpler
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf -mlss_id 40130 $(mysql-ens-compara-prod-3-ensadmin details hive)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            'division'      => 'vertebrates',

            # misc parameters
            'binary_species_tree_input_file' => $self->o('binary_species_tree'), # you can define your own species_tree for 'CAFE'. It *has* to be binary

            # CAFE parameters
            'do_cafe'  => 1,
            # Use production names here
            'cafe_species'          => ['danio_rerio', 'taeniopygia_guttata', 'callithrix_jacchus', 'pan_troglodytes', 'homo_sapiens', 'mus_musculus'],

        # HighConfidenceOrthologs Parameters
        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Apes', 'Murinae' ],
                'thresholds'    => [ 75, 75, 80 ],
            },
            {
                'taxa'          => [ 'Mammalia', 'Aves', 'Percomorpha' ],
                'thresholds'    => [ 75, 75, 50 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
        ],
    };
} 

sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    $analyses_by_name->{'make_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;
    $analyses_by_name->{'make_full_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;
}

1;
