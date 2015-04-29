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

#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    webmaster@sanger.ac.uk
# Created:       2001
#
package Sanger::Graphics::Glyph;
use strict;
use warnings;
no warnings qw(uninitialized);
use Sanger::Graphics::ColourMap;
use vars qw($AUTOLOAD);

#########
# constructor
# _methods is a hash of valid methods you can call on this object
#
sub new {
  my ($class, $params_ref) = @_;
  (my $module = $class) =~ s/Sanger::Graphics/EnsEMBL::Draw/;
  warn "########### Module $class is deprecated and will be removed in release 82. Please update your code to use $module instead";
  my $self = {
	      'background' => 'transparent',
	      'composite'  => undef,          # arrayref for Glyph::Composite to store other glyphs in
	      'points'     => [],             # listref for Glyph::Poly to store x,y paired points
	      (ref $params_ref eq 'HASH')?%{$params_ref} : (),
	     };
  bless $self, $class;
  return $self;
}

#########
# read-write methods
#
sub AUTOLOAD {
  my ($self, $val) = @_;
  no strict 'refs';
  (my $field      = $AUTOLOAD) =~ s/.*:://mx;
  *{$AUTOLOAD}    = sub {
    if(defined $_[1]) {
      $_[0]->{$field} = $_[1];
    }
    return $_[0]->{$field};
  };
  use strict;

  if(defined $val) {
    $self->{$field} = $val;
  }
  return $self->{$field};
}

#sub alt {
#  my $self = shift;
#  return $self->id();
#}

#########
# apply a transformation.
# pass in a hashref containing keys
#  - translatex
#  - translatey
#  - scalex
#  - scaley
#
sub transform {
  my ($self, $transform_ref) = @_;

  my $scalex     = $transform_ref->{'scalex'} || 1;
  my $scaley     = $transform_ref->{'scaley'} || 1;
  my $scalewidth = $scalex;
  my $translatex = $transform_ref->{'translatex'};
  my $translatey = $transform_ref->{'translatey'};

  #########
  # override transformation if we've set x/y to be absolute (pixel) coords
  #
  if($self->{'absolutex'})     { $scalex     = $transform_ref->{'absolutescalex'}; }
  if($self->{'absolutewidth'}) { $scalewidth = $transform_ref->{'absolutescalex'}; }
  if($self->{'absoltey'})      { $scaley     = $transform_ref->{'absolutescaley'}; }

  #########
  # copy the real coords & sizes if we don't have them already
  #
  $self->{'pixelx'}      ||= ($self->{'x'}      || 0);
  $self->{'pixely'}      ||= ($self->{'y'}      || 0);
  $self->{'pixelwidth'}  ||= ($self->{'width'}  || 0);
  $self->{'pixelheight'} ||= ($self->{'height'} || 0);

  #########
  # apply scale
  #
  if(defined $scalex) {
    $self->{'pixelx'}      = $self->{'pixelx'} * $scalex;
  }

  if(defined $scalewidth) {
    $self->{'pixelwidth'}  = $self->{'pixelwidth'}  * $scalewidth;
  }

  if(defined $scaley) {
    $self->{'pixely'}      = $self->{'pixely'}      * $scaley;
    $self->{'pixelheight'} = $self->{'pixelheight'} * $scaley;
  }

  #########
  # apply translation
  #
  $translatex and $self->pixelx($self->pixelx() + $translatex);
  $translatey and $self->pixely($self->pixely() + $translatey);
  return;
}

sub centre {
  my ($self, $arg) = @_;

  my ($x, $y);
  $arg ||= q();

  if($arg eq 'px') {
    #########
    # return calculated px coords
    # pixel coordinates are only available after a transformation has been applied
    #
    $x = $self->{'pixelx'} + $self->{'pixelwidth'} / 2;
    $y = $self->{'pixely'} + $self->{'pixelheight'} / 2;

  } else {
    #########
    # return calculated bp coords
    #
    $x = $self->{'x'} + $self->{'width'} / 2;
    $y = $self->{'y'} + $self->height() / 2;
  }

  return ($x, $y);
}

sub pixelcentre {
  my ($self) = @_;
  return ($self->centre('px'));
}

sub end {
  my ($self) = @_;
  return $self->{'x'} + $self->{'width'};
}

1;
