package Bio::EnsEMBL::GlyphSet::v_line;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  
  my $strand = $self->strand;

  my $strand_flag    = $self->my_config('strand');

  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );

  my $len            = $self->{'container'}->length();
  my $global_start   = $self->{'container'}->start();
  my $global_end     = $self->{'container'}->end();
  my $im_width       = $self->image_width();

  my @common = ( 'z' => 1000, 'colour' => 'red', 'absolutex' => 1, 'absolutey' => 1, 'absolutewidth' => 1 );

  ## Draw empty lines at the top and the bottom of the image(strand 'r')
  my $start = int(($im_width)/2);
  my $line = $self->Line({ 'x' => $start, 'y' => 0, 'width' => 0, 'height' => 0, @common });
  
  ## Links the 2 lines in a vertical one, in the middle of the image
  $self->join_tag($line, "v_line_$start", 0, 0, 'red', 'fill', 10);
        
  $self->push($line);
}

1;
