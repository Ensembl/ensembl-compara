package Bio::EnsEMBL::GlyphSet::navigation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  if ($self->{'container'}->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    my $line = $self->Rect({
      'z'             => 11,
      'x'             => -120,
      'y'             => 4,
      'colour'        => 'black',
      'width'         => 20000,
      'height'        => 0,
      'absolutex'     => 1,
      'absolutewidth' => 1,
      'absolutey'     => 1
    });
    
    $self->push($line);
    
    return;
  }

  my $href = $self->get_parameter('base_url') . ';action=%s;id=' . --[split '|', $self->get_parameter('slice_number')]->[0];
  
  my $sprite_size = 20;
  my $sprite_pad = 3;
  my $sprite_step = $sprite_size + $sprite_pad;

  my $sprites = {
    'nav'   => [ 
      -10 - $sprite_size, 
      -$sprite_step,
      [ 'zoom_out', 'out' ],
      [ 'realign',  'realign' ],
      [ 'zoom_in',  'in' ]
    ],
    'left'  => [ 
      0, 
      $sprite_step,
      [ 'left',       'left2' ],
      [ 'nudge_left', 'left' ]
    ],
    'right' => [ 
      $self->image_width - $sprite_size + 1, 
      -$sprite_step,
      [ 'right',       'right2' ],
      [ 'nudge_right', 'right' ]
    ]
  };

  if (!$self->{'config'}->{'align_slice'}) {
    # in case of AlignSlice - don't display navigation buttons
    push @{$sprites->{'nav'}}, [ 'flip_strand', 'flip' ], [ 'set_as_primary', 'primary' ] if $self->get_parameter('compara') eq 'secondary';

    foreach my $key (keys %$sprites) {
      my ($pos, $step,  @sprite_array) = @{$sprites->{$key}};
      
      foreach my $sprite (@sprite_array) {
        (my $alt = $sprite->[0]) =~ s/_/ /g;
        
        $self->push($self->Sprite({
          'z'             => 1000,
          'x'             => $pos,
          'y'             => 0,
          'sprite'        => $sprite->[0],
          'width'         => $sprite_size,
          'height'        => $sprite_size,
          'absolutex'     => 1,
          'absolutewidth' => 1,
          'absolutey'     => 1,
          'href'          => sprintf($href, $sprite->[1]),
          'class'         => 'nav',
          'alt'           => ucfirst $alt
        }));
        
        $pos += $step;
      }
    }
  }

  my $line = $self->Rect({
    'z'             => 11,
    'x'             => -120,
    'y'             => 12,
    'colour'        => 'black',
    'width'         => 120,
    'height'        => 0,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    'absolutey'     => 1
  });
  
  $self->join_tag($line, 'bracket', 0, 0, 'black');
  
  if ($self->get_parameter('compara') eq 'primary') {
    $self->join_tag($line, 'bracket2', 0.9, 0, 'rosybrown1', 'fill', -40);
    $self->join_tag($line, 'bracket2', 0,   0, 'rosybrown1', 'fill', -40);
  }
  
  $self->push($line);
  
  my $line = $self->Rect({
    'z'             => 11,
    'x'             => 0,
    'y'             => 12,
    'colour'        => 'black',
    'width'         => 20000,
    'height'        => 0,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    'absolutey'     => 1
  });

  $self->push($line);
}

1;
