=pod

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

Bio::EnsEMBL::Compara::PipeConfig::Plants::OrthologQM_Alignment_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::OrthologQM_Alignment_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

    This pipeline uses whole genome alignments to calculate the coverage of homologous pairs
    for Plants. See parent class Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf
    for additional information.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::OrthologQM_Alignment_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'      => 'plants',
        'member_type'   => 'protein',
        'species_set_name' => 'collection-plants',

        'homology_method_link_types' => ['ENSEMBL_ORTHOLOGUES', 'ENSEMBL_HOMOEOLOGUES'],
    };
}

1;
