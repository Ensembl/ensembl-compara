=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::P_variation_legend;

### Legend for P_variation.pm

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self = shift;
  
  my $config   = $self->{'config'};
  my $features = $config->{'P_variation_legend'};
  
  return unless $features;
 
  $self->init_legend(4);
 
  my %labels   = map { $_->SO_term => [ $_->rank, $_->label ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  $labels{'Insert'} = [ 9e9,     'Insert' ];
  $labels{'Delete'} = [ 9e9 + 1, 'Delete' ];
 
  foreach (sort { $labels{$a}[0] <=> $labels{$b}[0] } keys %$features) {
    my $text   = $labels{$_}[1];
    
    if ($features->{$_}{'shape'} eq 'Triangle') {
      $self->add_to_legend({
        legend => $text,
        style  => 'triangle',
        direction => $text eq 'Insert'?'down':'up',
        border => 'black',
        width => 5,
        height => 5,
      });
    } else {
      $self->add_to_legend({
        legend => $text,
        colour => $features->{$_}{'colour'},
        width  => 4,
        height => 4,
      });
    }
  }

  $self->add_to_legend({
        legend => 'Substitution',
        border => 'black',
        width => 4,
        height => 4,
  });
}

1;
        
