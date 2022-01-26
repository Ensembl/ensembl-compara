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

package EnsEMBL::Web::TextSequence::Markup::Conservation;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  my $cons_threshold = int((scalar(@$sequence) + 1) / 2); # Regions where more than 50% of bps match considered "conserved"
  my $conserved      = 0;
  
  for my $i (0..$config->{'length'} - 1) {
    my %cons;
    $cons{$_->legacy->[$i]{'letter'}}++ for @$sequence;

    my $c = join '', grep { $_ !~ /~|[-.N]/ && $cons{$_} > $cons_threshold } keys %cons;
       
    foreach (@$sequence) {
      next unless $_->legacy->[$i]{'letter'} eq $c; 
    
      $_->legacy->[$i]{'class'} .= 'con ';
      $conserved = 1;
    }   
  }
  
  $config->{'key'}{'other'}{'conservation'} = 1 if $conserved;
}

1;
