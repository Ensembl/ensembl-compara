=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Annotation::Protein::Exons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $slice_data, $markup) = @_;

  my $exons = $config->{'peptide_splice_sites'};
  my $flip  = 0;

  foreach (sort {$a <=> $b} keys %$exons) {
    last if $_ >= $config->{'length'};
  
    if ($exons->{$_}->{'exon'}) {
      $flip = 1 - $flip;
      push @{$markup->{'exons'}->{$_}->{'type'}}, "exon$flip";
    } elsif ($exons->{$_}->{'overlap'}) {
      push @{$markup->{'exons'}->{$_}->{'type'}}, 'exon2';
    }   
  }   
  
  $markup->{'exons'}->{0}->{'type'} = [ 'exon0' ];
}

1;
