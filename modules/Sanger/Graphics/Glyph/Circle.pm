package Sanger::Graphics::Glyph::Circle;
use strict;
use vars qw(@ISA);
use Sanger::Graphics::Glyph;
@ISA = qw(Sanger::Graphics::Glyph);


#  The constructor for a circle should be as follows:

#        my $circle = Sanger::Graphics::Glyph::Circle->new({
#            'x'         => 50,
#            'y'         => 50,
#            'width'     => 1,    #(bases|pixels)
#            'pixperbp'  => $pix_per_bp,
#            'absolutewidth' => undef|1, # (undef=bases, 1=pixes)
#            'colour'    => $colour,
#            'filled'    => 1,              # to have a filled circle
#        });

#########
# constructor
# _methods is a hash of valid methods you can call on this object
#
sub new {
  my ($class, $params_ref) = @_;
  my $self = {
	      'background' => 'transparent',
	      'composite'  => undef,          # arrayref for Glyph::Composite to store other glyphs in
	      'points'     => [],		        # listref for Glyph::Poly to store x,y paired points
	      ref($params_ref) eq 'HASH' ? %$params_ref : ()
	     };
  
  $self->{'absoluteheight'} = $self->{'absolutewidth'};
  bless($self, $class);
  
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

sub pixelheight {
  my ($self) = @_;
  return $self->pixelwidth();
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
