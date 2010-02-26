package Bio::EnsEMBL::GlyphSet::sequence;

use strict;

use Bio::EnsEMBL::Feature;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub features {
  my ($self) = @_;
  my $start  = 0;
  my $seq    = uc $self->{'container'}->seq;
  my $strand = $self->strand;
  
  $seq =~ tr/ACGT/TGCA/ if $strand == -1;
  
  my @features = map {
    Bio::EnsEMBL::Feature->new(
      -start   => ++$start,
      -end     => $start,
      -strand  => $strand,
      -seqname => $_,
    )
  } split //, $seq;
  
  return \@features;
}

# What to use as the colour key
sub colour_key {
  my ($self, $f) = @_;
  return lc $f->seqname;
}

# What to place on the feature
sub feature_label {
  my ($self, $f) = @_;
  return ($f->seqname, 'overlaid');
}

sub title {
  my ($self, $f) = @_;
  return sprintf '%s; Position: %s:%s', $f->seqname, $self->{'container'}->seq_region_name, $self->{'container'}->start + $f->start - 1;
}

sub fixed { return 1; }

1;
