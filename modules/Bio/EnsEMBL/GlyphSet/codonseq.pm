package Bio::EnsEMBL::GlyphSet::codonseq;

use strict;

use Bio::EnsEMBL::Feature;
use Bio::Seq;

use base qw(Bio::EnsEMBL::GlyphSet::sequence);

## We base this on the sequence drawing as the only
## code which is different is the code that gets
## the features...

## We have to create fake features in the features call...
sub features {
  my ($self) = @_;
  my $seq = $self->{'container'}->subseq(-2,$self->{'container'}->length+4);
  my $strand = $self->strand;
  my @features;
  foreach my $phase ( 0..2 ) {
    my $string = substr( $seq, $phase , 3 * int ( (length($seq) - $phase)/3 ) );
    if($strand == -1 ) { # Reverse complement sequence...
       $string = reverse $string;
       $string =~tr/AGCTagct/TCGAtcga/ ;
    }
    my $bioseq = new Bio::Seq( -seq => $string, -moltype => 'dna' );
    $string = $bioseq->translate->seq;
    $string = reverse $string if $strand == -1;
    my $start = $phase - 5;
    push @features, map {Bio::EnsEMBL::Feature->new(
      -start => $start+=3,
      -end   => $start+2,
      -seqname => $_,
      -strand  => $strand
    )} split //, $string;
  }
  return \@features;
}

1;
