package Bio::EnsEMBL::GlyphSet::gcplot;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use  Sanger::Graphics::Bump;

sub _init {
  my ($self) = @_;

  my $slice = $self->{'container'};

    # check we are not in a big gap!
  return unless @{$slice->project('seqlevel')};

  my $Config          = $self->{'config'};
  my $vclen           = $slice->length();
  return if ($vclen < 10000);    # don't want a GC plot for very short sequences

  my $h               = 20;
  my $colour          = $self->my_config('col')  || 'gray50';
  my $line_colour     = $self->my_config('line') || 'red';
   
  my $im_width        = $Config->image_width();
  my $divs            = int($im_width/2);
  my $divlen          = $vclen/$divs;
    
    #print STDERR "Divs = $divs\n";
  my $seq = $slice->seq();
  my @gc  = ();
    
  foreach my $i ( 0..($divs-1) ) {
    my $subseq = substr($seq, int($i*$divlen), int($divlen));
    my $GC     = $subseq =~ tr/GC/GC/;
    my $value  = 9999;
    if( length($subseq)>0 ) { # catch divide by zero....
      $value = $GC / length($subseq);
      $value = $value < .25 ? 0 : ($value >.75 ? .5 : $value -.25);
    }
    push @gc, $value;
  }
        
  my $value = shift @gc;
  my $x = 0;

  foreach my $new (@gc) {
    unless($value==9999 || $new==9999) {
      $self->push($self->Line({
        'x'            => $x,
        'y'            => $h* (1-2*$value),
        'width'        => $divlen,
        'height'       => ($value - $new)*2*$h,
        'colour'       => $colour,
        'absolutey'    => 1,
      })); 
    }
    $value    = $new;
    $x       += $divlen;
  }
  $self->push($self->Line({
    'x'         => 0,
    'y'         => $h/2, # 50% point for line
    'width'     => $vclen,
    'height'    => 0,
    'colour'    => $line_colour,
    'absolutey' => 1,
  }));
}            
1;

