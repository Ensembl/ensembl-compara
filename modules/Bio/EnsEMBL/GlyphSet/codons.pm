package Bio::EnsEMBL::GlyphSet::codons;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $container  = $self->{'container'};

  my $height     = 3;  # Pixels in height for glyphset
  my $padding    = 1;  # Padding
  my $max_length = $self->my_config('threshold') || 50; # In Kbases...
  my $stop_col   = $self->my_colour( 'stop'  ) || 'red';
  my $start_col  = $self->my_colour( 'start' ) || 'green';

# This is the threshold calculation to display the start/stop codon track warning
# if the track length is too long.
  return $self->errorTrack("Start/Stop codons only displayed for less than $max_length Kb.") 
    unless $container->length < $max_length*1001;

  my ($data,$offset,$strand,$base);

  if($self->cache('__codon__cache__')) {
# Reverse strand (2nd to display) so we retrieve information from the codon cache  
    $offset = 3;               # For drawing loop look at elements 3,4, 7,8, 11,12
    $strand = -1;              # Reverse strand
    $base   = 6 * $height + 3 * $padding;  # Start at the bottom
    $data   = $self->cache('__codon__cache__'); # retrieve data from cache
  } else {
    $offset = 1;               # For drawing loop look at elements 1,2, 5,6, 9,10
    $strand = 1;               # Forward strand
    $base   = 0;               # Start at the top
# As this is the first time around we will have to create the cache in the @data array    
    my $seq = $container->seq();          # Get the sequence
# 13 blank arrays so the display loop doesn't error {under -w}
    $data = [ undef,[],[],[],[],[],[],[],[],[],[],[],[] ];
# Start/stop codons on the forward strand have value 1/2
# Start/stop codons on the reverse strand have value 3/4
    my %h = qw( ATG 1 TAA 2 TAG 2 TGA 2 CAT 3 TTA 4 CTA 4 TCA 4 );
# The value is used as the index in the array to store the information. 
#    [ For each "phase" this is incremented by 4 ]
    foreach my $phase(0..2) {
      pos($seq) = $phase;
# Perl regexp from hell! Well not really but it's a fun line anyway....      
#    step through the string three characters at a time
#    if the three characters are in the h (codon hash) then
#    we push the co-ordinate element on to the $v'th array in the $data
#    array. Also update the current offset by 3...
      while( $seq =~ /(...)/g ) {
        push @{$data->[$h{$1}]},pos($seq)-3 if $h{$1};
      }
# At the end of the phase loop lets move the storage indexes forward by 4
      $h{$_} += 4 foreach keys %h;
    }
# Store the information in the codon cache for the reverse strand
    $self->cache('__codon__cache__',$data);
  }
# The twelve elements in the @data array, 
#    @{$config->{'__codon__cache__'}}
# are:
#  1 => coordinates of phase 0 start codons on forward-> strand
#  2 => coordinates of phase 0 stop  codons on forward-> strand
#  3 => coordinates of phase 0 start codons on <-reverse strand
#  4 => coordinates of phase 0 stop  codons on <-reverse strand
#
#  5 => coordinates of phase 2 start codons on forward-> strand
#  6 => coordinates of phase 2 stop  codons on forward-> strand
#  7 => coordinates of phase 2 start codons on <-reverse strand
#  8 => coordinates of phase 2 stop  codons on <-reverse strand
#
#  9 => coordinates of phase 3 start codons on forward-> strand
# 10 => coordinates of phase 3 stop  codons on forward-> strand
# 11 => coordinates of phase 3 start codons on <-reverse strand
# 12 => coordinates of phase 3 stop  codons on <-reverse strand
  my $fullheight = $height * 2 + $padding; 
  foreach my $phase (0..2){
    # Glyphs are 3 basepairs wide 
    foreach(@{$data->[ $offset + $phase * 4 ]}) { # start codon info
      my $glyph = $self->Rect({
        'x'         => $_,
        'y'         => $base + (2-$phase) * $fullheight * $strand,
        'width'     => 3,
        'height'    => $height-1,
        'colour'    => $start_col,
        'absolutey' => 1,
      });
      $self->push($glyph);
    }
    foreach(@{$data->[ $offset + $phase * 4 + 1]}) {
      my $glyph = $self->Rect({
        'x'         => $_,
        'y'         => $base + ((2-$phase) * $fullheight + $height) * $strand,
        'width'     => 3,
        'height'    => $height-1,
        'colour'    => $stop_col,
        'absolutey' => 1,
      });
      $self->push($glyph);
    }
  }
}
1;
