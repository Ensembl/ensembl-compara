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

#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2003
#
package EnsEMBL::Draw::Glyph::Circle;
use strict;
use base qw(EnsEMBL::Draw::Glyph);

#  The constructor for a circle should be as follows:

#        my $circle = EnsEMBL::Draw::Glyph::Circle->new({
#            'x'         => 50,
#            'y'         => 50,
#            'diameter'  => 2,    #(bases|pixels)
#            'radius'    => 1,    #(bases|pixels)  : specify one of width|diameter|radius
#            'pixperbp'  => $pix_per_bp,
#            'absolutewidth' => undef|1, # (undef=bases, 1=pixels)
#            'colour'    => $colour,
#            'filled'    => 1,              # to have a filled circle
#        });

sub new {
  my ($class, $params_ref) = @_;
  my $self = $class->SUPER::new($params_ref);

  $self->{'absoluteheight'} = $self->{'absolutewidth'};
  $self->{'width'}        ||= $self->{'diameter'};
  $self->{'width'}        ||= $self->{'radius'} * 2;

  return $self;
}

sub pixelcentre {
  my ($self)  = @_;
  return ($self->{'pixelx'}, $self->{'pixely'});
}

sub centre {
  my ($self) = @_;
  return ($self->{'x'}, $self->{'y'});
}

sub transform {
  my ($self, @args) = @_;
  $self->SUPER::transform(@args);
  $self->{'pixelheight'} = $self->{'pixelwidth'};
}

sub height {
  my ($self) = @_;

  if($self->{'absolutewidth'}) {
    return $self->{'width'};
  } else {
    return $self->{'width'} * ($self->{'pixperbp'} || 1);
  }
}

sub x {
  my ($self, $val) = @_;
  my $w = $self->width() / 2;
  $self->{'x'} = $val + $w if(defined $val);
  return $self->{'x'} - $w;
}

sub y {
  my ($self, $val) = @_;
  my $w = $self->height() / 2;
  $self->{'y'} = $val + $w if(defined $val);
  return $self->{'y'} - $w;
}

1;
