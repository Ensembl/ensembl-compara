package Bio::EnsEMBL::GlyphSet::Videogram_legend;

use strict;

use Sanger::Graphics::Bump;

use base qw(Bio::EnsEMBL::GlyphSet);

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
    'href'=>$details->{'href'},'zmenu'     => $details->{'zmenu'}
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
    'href'=>$details->{'href'},'zmenu'         => $details->{'zmenu'}
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
    'href'=>$details->{'href'},'zmenu'         => $details->{'zmenu'}
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
    'href'=>$details->{'href'},'zmenu'         => $details->{'zmenu'}
  });
}

sub highlight_bowtie {
  my $self = shift;
  my $details = shift;
  return $self->Poly({
    'points'    => [
      $details->{'mid'},                        $details->{'h_offset'},
      $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
      $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
      $details->{'mid'},                        $details->{'h_offset'},
      $details->{'mid'},                        $details->{'h_offset'}+$details->{'wid'},
      $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
      $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
      $details->{'mid'},                        $details->{'h_offset'}+$details->{'wid'}
    ],
    'colour'    => $details->{'col'},
    'absolutey' => 1,
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

sub highlight_lharrow {
  my $self = shift;
  my $details = shift;
  return $self->Poly({
    'points' => [ $details->{'mid'}, $details->{'h_offset'},
      $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
      $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'}
    ],
    'colour' => $details->{'col'},
    'absolutey' => 1,
    'href'=>$details->{'href'},'zmenu'  => $details->{'zmenu'}
  });
}

sub highlight_rharrow {
  my $self = shift;
  my $details = shift;
  return $self->Poly({
    'points' => [ 
      $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
      $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
      $details->{'mid'}, $details->{'h_offset'}+$details->{'wid'}
    ],
    'colour' => $details->{'col'},
    'absolutey' => 1,
    'href'=>$details->{'href'},'zmenu'  => $details->{'zmenu'}
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
