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

# A barcode is a visual representation of a set of features or values as
# blocks at regularly-spaced intervals. It is essentially a lot of
# rectangles in a row, but implemented more efficiently.
#
# If wiggle is set, however, it is drawn as a wiggle, rather than as a
# barcode and the value is the maximum score.
# That's quite a challenge to the Glyph's name, sadly.
#
# { values    => [... , ... , ...],
#   x         => $leftmost_coord,
#   y         => $topmost_coord,
#   height    => $height,
#   unit      => $one_step_x,
#   width     => $ignored, # always calculated as @$values*$unit
#   absolutex => $if_in_px_not_bp,
#   colours   => [ ... , ... , ... ],
#   max       => $maximum_score
#   wiggle    => $draw_as_wiggle_not_barcode
# }

package EnsEMBL::Draw::Glyph::Barcode;
use strict;
use base qw(EnsEMBL::Draw::Glyph);

sub x { return $_[0]->{'x'}; }
sub y { return $_[0]->{'y'}; }
sub y_transform { $_[0]->{'y'} += $_[1]; }
sub width { return @{$_[0]->{'values'}} * $_[0]->{'unit'}; }
sub height { return $_[0]->{'height'}; }

sub transform {
  my ($self, $transform_ref) = @_;

  $self->{'width'} = $self->width();

  my $scalex     = $$transform_ref{'scalex'};
  my $scaley     = $$transform_ref{'scaley'};
  my $translatex = $$transform_ref{'translatex'};
  my $translatey = $$transform_ref{'translatey'};

  $self->{'pixelpoints'} ||= [ @{$self->{'values'}} ];
  
  $scalex = $$transform_ref{'absolutescalex'} if $self->absolutex();
  $scaley = $$transform_ref{'absolutescaley'} if $self->absolutey();

  $self->{'pixelx'}      ||= ($self->{'x'}      || 0);
  $self->{'pixely'}      ||= ($self->{'y'}      || 0);
  $self->{'pixelwidth'}  ||= ($self->{'width'}  || 0);
  $self->{'pixelheight'} ||= ($self->{'height'} || 0);
  $self->{'pixelunit'}   ||= ($self->{'unit'}   || 0);

  $self->{'pixelx'}      *= ($scalex||1);
  $self->{'pixelwidth'}  *= ($scalex||1);
  $self->{'pixelunit'}   *= ($scalex||1);
  $self->{'pixely'}      *= ($scaley||1);
  $self->{'pixelheight'} *= ($scaley||1);
  $self->{'wiggley'}     *= ($scaley||1) if $self->{'wiggley'};

  $self->{'pixelx'}      += $translatex;
  $self->{'pixely'}      += $translatey;
}
1;

