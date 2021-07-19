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

package EnsEMBL::Draw::GlyphSet::Videogram_legend;

### Module for drawing "highlights" (aka pointers) on
### vertical ideogram images, including user data
###
### (Note that despite its name, this module is not currently
### used to draw a legend for vertical ideogram tracks)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config    = $self->{'config'};
  my $Container = $self->{'container'};
  my $fn = "highlight_$Container";
  $self->push( $self->fn( ) ) if $self->can($fn);
}

sub highlight_box {
  my $self = shift;
  my $details = shift;
  return $self->Rect({
    'x'         => $details->{'start'},
    'y'         => $details->{'h_offset'},
    'width'     => $details->{'end'}-$details->{'start'},
    'height'    => $details->{'wid'},
    'colour'    => $details->{'col'},
    'absolutey' => 1,
    'href'      => $details->{'href'},
    'zmenu'     => $details->{'zmenu'}
  });
}

sub highlight_filledwidebox {
  my $self = shift;
  my $details = shift;
  return $self->Rect({
    'x'             => $details->{'start'},
    'y'             => $details->{'h_offset'}-$details->{'padding'},
    'width'         => $details->{'end'}-$details->{'start'},
    'height'        => $details->{'wid'}+$details->{'padding'}*2,
    'colour'        => $details->{'col'},
    'absolutey'     => 1,
    'href'          => $details->{'href'},
    'zmenu'         => $details->{'zmenu'}
  });
}

sub highlight_widebox {
  my $self = shift;
  my $details = shift;
  return $self->Rect({
    'x'             => $details->{'start'},
    'y'             => $details->{'h_offset'}-$details->{'padding'},
    'width'         => $details->{'end'}-$details->{'start'},
    'height'        => $details->{'wid'}+$details->{'padding'}*2,
    'bordercolour'  => $details->{'col'},
    'absolutey'     => 1,
    'href'          => $details->{'href'},
    'zmenu'         => $details->{'zmenu'}
  });
}

sub highlight_outbox {
  my $self = shift;
  my $details = shift;
  return $self->Rect({
    'x'             => $details->{'start'} - $details->{'padding2'} *1.5,
    'y'             => $details->{'h_offset'}-$details->{'padding'} *1.5,
    'width'         => $details->{'end'}-$details->{'start'} + $details->{'padding2'} * 3,
    'height'        => $details->{'wid'}+$details->{'padding'}*3,
    'bordercolour'  => $details->{'col'},
    'absolutey'     => 1,
    'href'          => $details->{'href'},
    'zmenu'         => $details->{'zmenu'}
  });
}

sub highlight_labelline {
  my $self = shift;
  my $details = shift;
  my $composite = $self->Composite();
  $composite->push(
  $self->Line({
    'x'         => $details->{'mid'},
    'y'         => $details->{'h_offset'}-$details->{'padding'},,
    'width'     => 0,
    'height'    => $details->{'wid'}+$details->{'padding'}*2,
    'colour'    => $details->{'col'},
    'absolutey' => 1,
    })
  );
  return $composite;
} 

sub highlight_wideline {
  my $self = shift;
  my $details = shift;
  return $self->Line({
    'x'         => $details->{'mid'},
    'y'         => $details->{'h_offset'}-$details->{'padding'},,
    'width'     => 0,
    'height'    => $details->{'wid'}+$details->{'padding'}*2,
    'colour'    => $details->{'col'},
    'absolutey' => 1,
  });
}

sub highlight_text {
  my $self = shift;
  my $details = shift;
  my $composite = $self->Composite();
  
  $composite->push($self->Rect({
    'x'             => $details->{'start'},
    'y'             => $details->{'h_offset'}-$details->{'padding'},
    'width'         => $details->{'end'}-$details->{'start'},
    'height'        => $details->{'wid'}+$details->{'padding'}*2,
    'bordercolour'  => $details->{'col'},
    'absolutey'     => 1,
  })
  );
  # text label for feature
  $composite->push ($self->Text({
    'x'         => $details->{'mid'}-$details->{'padding2'},
    'y'         => $details->{'wid'}+$details->{'padding'}*3,
    'width'     => 0,
    'height'    => $details->{'wid'},
    'font'      => 'Tiny',
    'colour'    => $details->{'col'},
    'text'      => $details->{'id'},
    'absolutey' => 1,
  }));
  # set up clickable area for complete graphic
  return $composite;
}

# Direction of arrows is rotated because the image is vertical
sub highlight_lharrow { return shift->highlight_arrow('down', $_[0]{'h_offset'},                  @_); }
sub highlight_rharrow { return shift->highlight_arrow('up',   $_[0]{'h_offset'} + $_[0]->{'wid'}, @_); }
sub highlight_bowtie  { my $self = shift; return ($self->highlight_lharrow(@_), $self->highlight_rharrow(@_)); }

sub highlight_arrow {
  my ($self, $direction, $mid_y, $details) = @_;
  
  return $self->Triangle({
    width     => $details->{'padding2'} * 2,
    height    => $details->{'padding'},
    direction => $direction,
    mid_point => [ $details->{'mid'}, $mid_y ],
    colour    => $details->{'col'},
    href      => $details->{'href'},
    zmenu     => $details->{'zmenu'},
    id        => $details->{'html_id'},
    absolutey => 1,
  });
}

sub highlight_rhbox {
  my ($self, $details) = @_;
  $details->{'strand'} = "+";
  return $self->highlight_strandedbox($details);
}

sub highlight_lhbox {
  my ($self, $details) = @_;
  $details->{'strand'} = "-";
  return $self->highlight_strandedbox($details);
}

sub highlight_strandedbox {
  my ($self, $details) = @_;
  my $strand           = $details->{'strand'} || "";
  my $draw_length      = $details->{'end'}-$details->{'start'};
  my $bump_start       = int($details->{'start'} * $self->{'pix_per_bp'});
  my $bump_end         = $bump_start + int($draw_length * $self->{'pix_per_bp'}) +1;
  my $ori              = ($strand eq "-")?-1:1;
  my $key              = $strand eq "-" ? "_bump_reverse" : "_bump_forward";
  my $row              = $self->bump_row( $bump_start, $bump_end, 0, $key );
  my $pos              = 7 + $ori*12 + $ori*$row*($details->{'padding'}+2);
  my $dep              = $self->my_config('dep');
  return $dep && $row>$dep-1 ? $self->Rect({
    'x'            => $details->{'start'},
    'y'            => $pos,
    'width'        => $draw_length, #$details->{'end'}-$details->{'start'},
    'height'       => $details->{'padding'},
    'colour'       => $details->{'col'},
    'absolutey'    => 1,
    'href'=>$details->{'href'},'zmenu'        => $details->{'zmenu'}
  }) : ();
}

1;
