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

package EnsEMBL::Web::TextSequence::Markup::VariationConservation;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup::Conservation);

sub replaces { return 'EnsEMBL::Web::TextSequence::Markup::Conservation'; }

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  my $difference = 0;
 
  for my $i (0..scalar(@$sequence)-1) {
    # XXX temporary hack for Compara_Alignments
   next unless $sequence->[$i]->is_root;

    next if $config->{'slices'}->[$i] and $config->{'slices'}->[$i]->{'no_alignment'};
    
    my $seq = $sequence->[$i]->legacy;
   
    for (0..$config->{'length'}-1) {
      next if $seq->[$_]->{'match'};
    
      $seq->[$_]->{'class'} .= 'dif ';
      $difference = 1;
    }   
  }
  
  $config->{'key'}->{'other'}{'difference'} = 1 if $difference;
}

1;
