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



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id <curr_ncrna_mlss_id>

=head1 EXAMPLES

e99
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf -mlss_id 40139 $(mysql-ens-compara-prod-7-ensadmin details hive)

e96
    # All the databases are defined in the production_reg_conf so the command-line is much simpler
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf -mlss_id 40130 $(mysql-ens-compara-prod-3-ensadmin details hive)


=head1 DESCRIPTION

This is the Vertebrates PipeConfig for the ncRNAtrees pipeline.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ncRNAtrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ncRNAtrees_conf');

sub default_options {
    my ($self) = @_;

    return {
            %{$self->SUPER::default_options},

            # Must be given on the command line
            #'mlss_id'          => 40100,

            'division'      => 'vertebrates',
            'collection'    => 'default',       # The name of the species-set within that division
            'pipeline_name' => $self->o('collection') . '_' . $self->o('division').'_ncrna_trees_'.$self->o('rel_with_suffix'),

            # CAFE parameters
            'initialise_cafe_pipeline'  => 1,
            # Use production names here
            'cafe_species'          => ['danio_rerio', 'taeniopygia_guttata', 'callithrix_jacchus', 'pan_troglodytes', 'homo_sapiens', 'mus_musculus'],
    };
} 

1;

