package Bio::EnsEMBL::GlyphSet::navigation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      my $line = $self->Rect({
	  'z' => 11,
	  'x' => -120,
	  'y' => 4, # 22,
	  'colour' => 'black',
	  'width' => 20000,
	  'height' => 0,
	  'absolutex'     => 1,
	  'absolutewidth' => 1,
	  'absolutey'     => 1,
      });
      
      $self->push($line);

      return;
  }

  # return unless ($self->strand() == 1);
  my $base_href = $self->{'config'}->{'base_url'};
  my $im_width       = $self->{'config'}->image_width();

  my $SPRITE_SIZE = 20;
  my $SPRITE_PAD = 3;
  my $SPRITE_STEP = $SPRITE_SIZE + $SPRITE_PAD;

  my $SPRITES = { 
    'nav'   => [ -10-$SPRITE_SIZE,             -$SPRITE_STEP, 
       ['zoom_out' => 'out'],
       ['realign'  => 'realign'],
       ['zoom_in'  => 'in']
    ],
    'left'  => [ 0,                             $SPRITE_STEP, 
      ['left'       => 'left2'],
      ['nudge_left' => 'left']
    ],
    'right' => [ $im_width - $SPRITE_SIZE + 1, -$SPRITE_STEP,
      ['right'      => 'right2'],
      ['nudge_right'=> 'right']
    ]
  };
 
  if(! ($self->{'config'}->{'align_slice'})) { 
# in case of AlignSlice - don't display navigation buttons
  push @{$SPRITES->{'nav'}}, 
    ['flip_strand'    => 'flip'],
    ['set_as_primary' => 'primary'] if $self->{'config'}->{'slice_number'};

  foreach my $key ( keys %$SPRITES ) {
    my( $pos, $step,  @sprite_array ) =  @{$SPRITES->{$key}};

    foreach my $sprite ( @sprite_array ) {
      (my $N = ucfirst($sprite->[0])) =~ s/_/ /g;
      $self->push($self->Sprite({
        'z'             => 1000,
        'x'             => $pos,
        'y'             => 0,
        'sprite'        => $sprite->[0],
        'width'         => $SPRITE_SIZE,
        'height'        => $SPRITE_SIZE,
        'id'            => $N,
        'absolutex'     => 1,
        'absolutewidth' => 1,
        'absolutey'     => 1,
        'href'          => "$base_href;action=$sprite->[1];id=$self->{'config'}->{'slice_number'}",
      }));
      $pos += $step;
    }
  }
}
  my $line = $self->Rect({
    'z' => 11,
    'x' => -120,
    'y' => 12, # 22,
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
  my $line = $self->Rect({
    'z' => 11,
    'x' => 0,
    'y' => 12, # 22,
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
        
