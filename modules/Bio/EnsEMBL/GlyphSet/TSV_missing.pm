package Bio::EnsEMBL::GlyphSet::TSV_missing;
use strict;
use Bio::EnsEMBL::GlyphSet;
our @ISA = qw(Bio::EnsEMBL::GlyphSet);


# The filter message refers to the number of SNPs removed from the 'snp_fake' track
# i.e. the number will not change if you filter on SARA SNPs

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $counts = $self->{'config'}->{'snp_counts'};
  return unless ref $counts eq 'ARRAY';
  
  my $text;
  if ($counts->[0]==0 ) {
    $text .= "There are no SNPs within the context selected for this transcript.";
  } elsif ($counts->[1] ==0 ) {
    $text .= "The options set in the drop down menu have filtered out all $counts->[0] variations in this region.";
  } elsif ($counts->[0] == $counts->[1] ) {
    $text .= "None of the variations are filtered out by the Source, Class and Type menus.";
  } else {
    $text .= ($counts->[0]-$counts->[1])." of the $counts->[0] variations in this region have been filtered out by the Source, Class and Type menus.";
  }
  $self->errorTrack( $text );

  # Context filter
  return unless defined $counts->[2];

  my $context_text;
  if ($counts->[2]==0) {
    $context_text = "None of the intronic variations are removed by the Context drop down filter.";
  }
  elsif ($counts->[2]==1) {
    $context_text = $counts->[2]." intronic variation has been removed by the Context drop down filter.";
  }
 else {
    $context_text = $counts->[2]." intronic variations are removed by the Context drop down filter.";
  }
  $self->errorTrack( $context_text, 0, 14 );
  return 1;
}

1;

