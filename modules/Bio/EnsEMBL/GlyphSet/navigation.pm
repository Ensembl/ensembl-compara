package Bio::EnsEMBL::GlyphSet::navigation;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Sprite;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;

sub init_label {
  return;
}

sub os { return $_[0]->{'config'}{'other_slices'}[$_[1]]; }

sub href_zoom_in {
  my $self = shift;
  my $cn = $self->{'config'}{'slice_number'};
  my $l  = $self->os($cn);
  return $self->href() unless $l->{'location'};
  my $w  = $l->{'location'}->length ;
  $cn = '' unless $cn;
  return $self->href( "w$cn" => int($w/2) );
}

sub href_zoom_out {
  my $self = shift;
  my $cn = $self->{'config'}{'slice_number'};
  my $l  = $self->os($cn);
  return $self->href() unless $l->{'location'};
  my $w  = $l->{'location'}->length ;
  $cn = '' unless $cn;
  return $self->href( "w$cn" => int($w*2) );
}

sub href_flip_strand {
  my $self = shift;
  my $cn = $self->{'config'}{'slice_number'};
  my $l  = $self->os($cn);
  if( $cn &&  $l->{'location'} ) {
    return $self->href( "c$cn" => join( ':', $l->{'location'}->seq_region_name, $l->{'location'}->centrepoint, $l->{'ori'} < 0 ? 1 : -1 ) );
  }
  return $self->href();
  
}

sub href_left  { return $_[0]->href_shift( -0.5 ); }
sub href_nudge_left   { return $_[0]->href_shift(  0.1 ); }
sub href_nudge_right  { return $_[0]->href_shift(  0.1 ); }
sub href_right { return $_[0]->href_shift(  0.5 ); }
 
sub href {
  my( $self , %param ) = @_;
  my $C = 0;
  foreach( @{ $self->{'config'}{'other_slices'}} ) {
    my $l = $self->os($C);
    my $CS = $C ? $C : '';
    unless( exists( $param{ "c$CS" } ) ) {
      if( $l->{'location'} ) {
        $param{ "c$CS" } = join( ':', $l->{'location'}->seq_region_name, $l->{'location'}->centrepoint, $l->{'ori'} < 0 ? -1 : 1 );
      }
    }
    unless( exists( $param{ "s$CS" } ) ) {
      $param{ "s$CS" } = $l->{'species'};
    }
    unless( exists( $param{ "w$CS" } ) ) {
      if( $l->{'location'} ) {
        $param{ "w$CS" } = $l->{'location'}->length;
      } 
    }
    $C++;
  }
  $param{'s'}||= $ENV{'ENSEMBL_SPECIES'};
  my $return = "/$param{'s'}/$ENV{'ENSEMBL_SCRIPT'}?". join '&', map { $_ eq 's' || !$param{$_} ? () : "$_=$param{$_}" } sort keys %param;
  return $return;
}

sub href_shift {
  my $self = shift; my $frac = shift;
  my $cn = $self->{'config'}{'slice_number'};
  my $l  = $self->os($cn);
  return $self->href() unless $l->{'location'};
  if( $cn ) {
    return $self->href( "c$cn" => join( ':', $l->{'location'}->seq_region_name, $l->{'location'}->centrepoint - $l->{'location'}->length * $frac, $l->{'ori'} ) );
  } else {
    return $self->href( "c" => join( ':', $l->{'location'}->seq_region_name, $l->{'location'}->centrepoint - $l->{'location'}->length * $frac, $l->{'ori'} ) );
  }
  
}

sub href_set_as_primary {
  my $self = shift;
  my $cn = $self->{'config'}{'slice_number'};
  if( $cn > 0 ) {
    my $l0 = $self->os(0);
    my $l  = $self->os($cn);
    return $self->href() unless $l->{'location'} && $l0->{'location'};
    my %param = (
      "c" => join( ':', $l->{'location'}->seq_region_name, $l->{'location'}->centrepoint ),
      "s" => $l->{'species'},
      "w" => $l->{'location'}->length,
      "c$cn" => join( ':', $l0->{'location'}->seq_region_name, $l0->{'location'}->centrepoint, $l->{'ori'} ),
      "s$cn" => $l0->{'species'},
      "w$cn" => $l0->{'location'}->length
    );
    my $C = 0;
    foreach( @{$self->{'config'}{'other_slices'}} ) {
      if($C>0 && $C!=$cn) {
        $param{"o$C"} = $l->{'ori'} * $self->os($C)->{'ori'} * $l->{'ori'} * $l0->{'ori'};
      }
      $C++;
    }
    return $self->href( %param );
  } else {
    return $self->href();
  }
}

sub href_realign {
  my $self = shift;
  my $cn = $self->{'config'}{'slice_number'};
  my %param = ();
  my $C = 0;
  foreach( @{$self->{'config'}{'other_slices'}} ) {
    if( $C && (!$cn || $C==$cn) ) {
      $param{ "c$C" } = undef;
      $param{ "w$C" } = undef;
    }
    $C++;
  }
  return $self->href( %param );
}

sub _init {
  my ($self) = @_;
  # return unless ($self->strand() == 1);

  my $im_width       = $self->{'config'}->image_width();

  my $SPRITE_SIZE = 20;
  my $SPRITE_PAD = 3;
  my $SPRITE_STEP = $SPRITE_SIZE + $SPRITE_PAD;

  my $SPRITES = { 
    'nav'   => [ -10-$SPRITE_SIZE,             -$SPRITE_STEP, 'zoom_out', 'realign', 'zoom_in' ],
    'left'  => [ 0,                             $SPRITE_STEP, 'left', 'nudge_left' ],
    'right' => [ $im_width - $SPRITE_SIZE + 1, -$SPRITE_STEP, 'right', 'nudge_right' ]
  };
 
  push @{$SPRITES->{'nav'}}, 'flip_strand', 'set_as_primary' if $self->{'config'}->{'slice_number'};
  foreach my $key ( keys %$SPRITES ) {
    my( $pos, $step,  @sprite_array ) =  @{$SPRITES->{$key}};

    foreach my $sprite ( @sprite_array ) {
      my $href = "href_$sprite"; 
      $href = $self->can($href)  ? $self->$href() : undef;
      (my $N = ucfirst($sprite)) =~ s/_/ /g;
      $self->push(new Sanger::Graphics::Glyph::Sprite({
        'z'             => 1000,
        'x'             => $pos,
        'y'             => 0,
        'sprite'        => $sprite,
        'width'         => $SPRITE_SIZE,
        'height'        => $SPRITE_SIZE,
        'id'           => $N,
        'absolutex'     => 1,
        'absolutewidth' => 1,
        'absolutey'     => 1,
        'href'          => $href,
      }));
      $pos += $step;
    }
  }
  my $line = new Sanger::Graphics::Glyph::Rect({
    'z' => 11,
    'x' => -120,
    'y' => 22,
    'colour' => 'black',
    'width' => 120,
    'height' => 0,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    'absolutey'     => 1,
  });
  $self->join_tag( $line, "bracket", 0,0, 'black' );
  if( $self->{'config'}->{'compara'} eq 'primary' ) {
    $self->join_tag( $line, "bracket2", 0.9,0, 'rosybrown1', 'fill', -40 );
    $self->join_tag( $line, "bracket2", 0,0, 'rosybrown1', 'fill', -40 );
  }
  $self->push($line);
  my $line = new Sanger::Graphics::Glyph::Rect({
    'z' => 11,
    'x' => 0,
    'y' => 22,
    'colour' => 'black',
    'width' => 20000,
    'height' => 0,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    'absolutey'     => 1,
  });

  $self->push($line);

}
1;
        
