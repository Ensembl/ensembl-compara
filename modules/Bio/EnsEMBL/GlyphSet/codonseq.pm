package Bio::EnsEMBL::GlyphSet::codonseq;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use strict;

## We have to create fake features in the features call...

use Bio::EnsEMBL::Feature;
use Bio::Seq;

sub fixed { return 1;} ## What does this mean...

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

sub colour {
  return $self->my_colour( $f->seqname );
}

## What to place on the feature...
sub feature_label {
  my( $self, $f ) = @_;
  return ( $f->seqname, 'overlaid' );
}

## No title...
sub title {
  return;
}

## No link...
sub href {
  return;
}

## No tags
sub tag {

}
1;
