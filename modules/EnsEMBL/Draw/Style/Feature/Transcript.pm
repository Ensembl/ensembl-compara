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

package EnsEMBL::Draw::Style::Feature::Transcript;

### Renders a track as a series of exons and introns 

use parent qw(EnsEMBL::Draw::Style::Feature::Structured);

sub draw_join {
  my ($self, %params) = @_;
  $params{'colour'} = $params{'join_colour'};
  delete $params{'join_colour'};
  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = 0;
    $params{'width'}     += $params{'x'};
  }
  push @{$self->glyphs}, $self->Intron(\%params);
}

sub draw_block {
  my ($self, %params) = @_;
  my $structure   = $params{'structure'};
  my $block_width = $params{'width'};

  if ($structure->{'non_coding'}) {
    $self->draw_noncoding_block(%params);
  }
  elsif ($structure->{'utr_5'}) {
    my $colour        = $params{'colour'};
    $params{'width'}  = $structure->{'utr_5'};
    $self->draw_noncoding_block(%params);
    $params{'x'}     += $structure->{'utr_5'};
    $params{'width'}  = $block_width - $structure->{'utr_5'};
    $params{'colour'} = $colour;
    $self->draw_coding_block(%params);
  }
  elsif ($structure->{'utr_3'}) {
    $params{'width'} = $structure->{'utr_3'};
    $self->draw_coding_block(%params);
    $params{'x'}    += $structure->{'utr_3'};
    $params{'width'} = $block_width - $structure->{'utr_3'};
    $self->draw_noncoding_block(%params);
  }
  else {
    $self->draw_coding_block(%params);
  }
}

sub draw_coding_block {
  my ($self, %params) = @_;
  delete $params{'structure'};
  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = 0;
    $params{'width'}     += $params{'x'};
  }
  push @{$self->glyphs}, $self->Rect(\%params);
}

sub draw_noncoding_block {
  my ($self, %params) = @_;
  $params{'bordercolour'} = $params{'colour'};
  delete $params{'colour'};
  $params{'height'} = $params{'height'} - 2;
  $params{'y'} += 1;
  delete $params{'structure'};
  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = 0;
    $params{'width'}     += $params{'x'};
  }
  push @{$self->glyphs}, $self->Rect(\%params);
}


1;
