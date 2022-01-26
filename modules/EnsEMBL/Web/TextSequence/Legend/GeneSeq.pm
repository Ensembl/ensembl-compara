=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Legend::GeneSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Legend);

sub extra_keys {
  my ($self, $config) = @_;

  my $exon_type;
  $exon_type = $config->{'exon_display'} unless $config->{'exon_display'} eq 'selected';
  $exon_type = 'All' if !$exon_type || $exon_type eq 'core';
  $exon_type = ucfirst $exon_type;

  return {
    exons => {
      gene    => { class => 'eg', text => "$config->{'gene_name'} $config->{'gene_exon_type'}" },
      other   => { class => 'eo', text => "$exon_type exons in this region" },
      compara => { class => 'e2', text => "$exon_type exons in this region" }
    }
  };
}

1;
