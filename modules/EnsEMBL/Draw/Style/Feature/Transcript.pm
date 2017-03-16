=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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
  my ($self, $composite, %params) = @_;

  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = 0;
    $params{'width'}     += $params{'x'};
  }

  ## Draw the join as a horizontal line or a "hat"?
  if ($self->track_config->get('collapsed')) {
    $params{'y'} += $params{'height'}/2;
    $params{'height'} = 0;
    push @{$self->glyphs}, $self->Line(\%params);
  }
  elsif ($params{'x'} == 0 || ($params{'x'} + $params{'width'} >= $self->image_config->container_width)) {
    ## Join goes off edge of image, so draw a horizontal dotted line
    $params{'y'} += $params{'height'}/2;
    $params{'height'} = 0;
    $params{'dotted'} = 1;
    $composite->push($self->Line(\%params));
  }
  else {
    $composite->push($self->Intron(\%params));
  }
}

sub draw_block {
  my ($self, $composite, %params) = @_;
  my $structure   = $params{'structure'};

  ## Calculate dimensions based on viewport, otherwise maths can go pear-shaped!
  my $start = $structure->{'start'};
  $start    = 0 if $start < 0;
  my $end   = $structure->{'end'};
  my $edge = $self->image_config->container_width;
  $end      = $edge if $end > $edge;  
  ## NOTE: for drawing purposes, the UTRs are defined with respect to the forward strand,
  ## not with respect to biology, because it makes the logic a lot simpler
  my $coding_start  = $structure->{'utr_5'} || $start;
  my $coding_end    = $structure->{'utr_3'} || $end;
  my $coding_width = $coding_end - $coding_start + 1;

  if ($structure->{'non_coding'}) {
    $self->draw_noncoding_block($composite, %params);
  }
  elsif (defined($structure->{'utr_5'}) || defined($structure->{'utr_3'})) {
    if (defined($structure->{'utr_5'})) {
      $params{'width'}  = $structure->{'utr_5'} - $start + 1;
      $self->draw_noncoding_block($composite, %params);
    }

    $params{'x'} = $coding_start - 1;
    $params{'width'} = $coding_width; 
    $self->draw_coding_block($composite, %params);

    if (defined($structure->{'utr_3'})) {
      $params{'x'}     = $structure->{'utr_3'} - 1;
      $params{'width'} = $end - $structure->{'utr_3'} + 1;
      $self->draw_noncoding_block($composite, %params);
    }
  }
  else {
    $self->draw_coding_block($composite, %params);
  }
}

sub draw_coding_block {
  my ($self, $composite, %params) = @_;
  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = 0;
    $params{'width'}     += $params{'x'};
  }
  delete $params{'structure'};
  $composite->push($self->Rect(\%params));
}

sub draw_noncoding_block {
  my ($self, $composite, %params) = @_;

  ## Now that we have used the correct coordinates, constrain to viewport
  if ($params{'x'} < 0) {
    $params{'x'}          = 0;
    $params{'width'}     += $params{'x'};
  }

  unless ($self->track_config->get('collapsed')) {
    ## Exons are shown as outlined blocks, except in collapsed view
    $params{'bordercolour'} = $params{'colour'};
    delete $params{'colour'};
    ## Make UTRs smaller than exons
    if (defined($structure->{'utr_5'}) || defined($structure->{'utr_3'})) {
      $params{'height'} = $params{'height'} - 2;
      $params{'y'} += 1;
    }
  }
  delete $params{'structure'};
  $composite->push($self->Rect(\%params));
}


1;
