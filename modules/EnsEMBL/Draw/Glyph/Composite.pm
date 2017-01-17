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

package EnsEMBL::Draw::Glyph::Composite;
use strict;
use base qw(EnsEMBL::Draw::Glyph);

sub push {
  my ($self) = shift;
  $self->_push_unshift('push',@_);
}

sub unshift {
  my ($self) = shift;
  $self->_push_unshift('unshift',@_);
}

sub _push_unshift {    
  my $self      = shift;
  my $direction = shift;
  
  for my $glyph ( ($direction eq 'push') ? @_ : reverse @_ ) {
    next unless $glyph;

    my $gx = $glyph->x();
    my $gw = $glyph->width();
    my $gy = $glyph->y();
    my $gh = $glyph->height();

    if($glyph->{'absolutewidth'}) {
      $self->{'pixperbp'} ||= $glyph->{'pixperbp'};
      ($gx,$gy) = $glyph->centre();
      $gx      -= $gw/(2 * $self->{'pixperbp'});
      $gy      -= $gw/2;
    }

    #########
    # taint ourselves with absolutewidth
    #
    $self->{'absolutewidth'} ||= $glyph->{'absolutewidth'};

    #########
    # track max and min dimensions
    # DO NOT use "||=" because zero is equivalent to undef and zero need to be kept
    #
    $self->{'x'}      = $gx unless defined $self->{'x'};
    $self->{'y'}      = $gy unless defined $self->{'y'};
    $self->{'width'}  = $gw unless defined $self->{'width'};
    $self->{'height'} = $gh unless defined $self->{'height'};

    #########
    # x
    #
    if($gx < $self->{'x'}) {
      my $offset        = $self->{'x'} - $gx;
      $self->{'x'}      = $gx;
      $self->{'width'} += $offset;
      
      #########
      # if the new glyph is set outside LHS boundary, then the composite stretches
      # and all glyphs already inside need to be offset by the difference
      #
      for my $offset_glyph (@{$self->{'composite'}}) {
	$offset_glyph->x($offset_glyph->x() + $offset);
      }
    }

    if(($gx + $gw) > ($self->x() + $self->width())) {
      #########
      # x unchanged
      #
      $self->{'width'} = $gx + $gw - $self->{'x'};
      
    }

    #########
    # y
    #
    if($gy < $self->y()) {
      my $offset         = $self->{'y'} - $gy;
      $self->{'y'}       = $gy;
      $self->{'height'} += $offset;
      
      #########
      # if the new glyph is set outside TOP boundary, then the composite stretches
      # and all glyphs already inside need to be offset by the difference
      #
      for my $offset_glyph (@{$self->{'composite'}}) {
	$offset_glyph->y($offset_glyph->y() + $offset);
      }
    }
    
    if(($gy + $gh) > ($self->{'y'} + $self->{'height'})) {
      #########
      # y unchanged
      #
      $self->{'height'} = $gy + $gh - $self->{'y'};
    }

    #########
    # make the glyph coords relative to the composite container
    # NOTE: watch out for this if you're creating glyphsets! - don't do this twice
    #
    unless($glyph->{'absolutex'}) {
      if($glyph->{'absolutewidth'}) {
	      $glyph->{'x'} = $gx - $self->{'x'}+$gw/(2 * $self->{'pixperbp'});
      } else {
	      $glyph->x($gx - $self->{'x'});
      }
    }

    unless($glyph->{'absolutey'}) {
      $glyph->y($gy - $self->{'y'});
    }

    if($glyph->{'absoluteheight'}) {
      $glyph->{'y'} = $gy - $self->{'y'}+ $gh/2;
    }

    if($direction eq 'push') {
      CORE::push @{$self->{'composite'}}, $glyph;
    } else {
      CORE::unshift @{$self->{'composite'}}, $glyph;
    }
  }
}

sub first {
  my ($self) = @_;
  return if(!defined $self->{'composite'});
  return @{$self->{'composite'}}[0];
}

sub last {
  my ($self) = @_;
  return if(!defined $self->{'composite'});
  my $len = scalar @{$self->{'composite'}};
  return undef if($len == 0);
  return @{$self->{'composite'}}[$len - 1];
}

sub glyphs {
  my ($self) = @_;
  return @{$self->{'composite'}};
}

sub transform {
  my ($self, $transform_obj) = @_;
  
  $self->SUPER::transform($transform_obj);
  
  for my $sg (@{$self->{'composite'}}) {
    my $tmp_transform = $transform_obj->clone;
    $tmp_transform->translatex($self->pixelx());
    $tmp_transform->translatey($self->pixely());
    $sg->transform($tmp_transform);
  }
}

1;
