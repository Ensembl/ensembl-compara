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

package EnsEMBL::Draw::Style::Feature::Tagged;

=pod
Renders a track as a series of simple rectangular blocks with 'tags' 
- triangular sections that denote a subtype of feature
=cut

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Draw a block with optional tags
  my ($self, $feature, $position) = @_;
  #use Data::Dumper; warn Dumper($feature);

  if ($feature->{'tag'}) {
    my ($pattern, $patterncolour, $notags);
    $pattern = $feature->{'pattern'};
    ($pattern, $patterncolour, $notags) = @$pattern if ref($pattern) eq 'ARRAY';

    my $colours = $feature->{'colour_lookup'};
    my $part    = $colours->{'part'};

    my %params = (
                  x         => $feature->{'start'} - 1,
                  y         => $position->{'y'},
                  h         => $position->{'height'},
                  width     => $position->{'width'},
                  colour    => $feature->{'colour'},
                  absolutey => 1,
                  );

    if ($part eq 'line') {
      push @{$self->glyphs}, $self->Space(\%params),
                              $self->Rect({ %params,
                                            y         => $position->{'height'}/2 + 1,
                                            height    => 0,
                                          });
    }
    elsif ($part eq 'invisible') { 
      push @{$self->glyphs}, $self->Space(\%params),
    } 
    elsif ($part eq 'align') {
      push @{$self->glyphs}, $self->Rect({  %params,
                                            z         => 20,
                                            height    => $h + 2,
                                            absolutez => 1,
                                          });
    }
    elsif ($part ne 'none') {
      my $colour_key = "$colours->{'part'}colour";
      push @{$self->glyphs}, $self->Rect({  %params,
                                            height        => $position->{'height'} + 2,
                                            $colour_key   => $colours->{'feature'},
                                            pattern       => $pattern,
                                            patterncolour => $patterncolour,
                                          });

    }
  }
  else {
    $self->SUPER::draw_feature($feature, $position);
  }
}

1;
