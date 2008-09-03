package Bio::EnsEMBL::GlyphSet::sequence;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use strict;

use Bio::EnsEMBL::Feature;

sub fixed { return 1;}

sub features {
  my ($self) = @_;
  my $start = 0;
  my $seq = uc($self->{'container'}->seq);
  my $strand = $self->strand;
  if($strand == -1 ) { $seq=~tr/ACGT/TGCA/; }
  my @features = map { Bio::EnsEMBL::Feature->new(
    -start   => ++$start,
    -end     => $start,
    -strand  => $strand,
    -seqname => $_,
  ) } split //, $seq;
  return \@features;
}

## What to use as the colour key...
sub colour {
  my( $self, $f ) = @_;
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
  return;
}
1;
