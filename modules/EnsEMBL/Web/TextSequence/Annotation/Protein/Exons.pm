package EnsEMBL::Web::TextSequence::Annotation::Protein::Exons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $slice_data, $markup) = @_;

  my $exons = $config->{'peptide_splice_sites'};
  my $flip  = 0;

  foreach (sort {$a <=> $b} keys %$exons) {
    last if $_ >= $config->{'length'};
  
    if ($exons->{$_}->{'exon'}) {
      $flip = 1 - $flip;
      push @{$markup->{'exons'}->{$_}->{'type'}}, "exon$flip";
    } elsif ($exons->{$_}->{'overlap'}) {
      push @{$markup->{'exons'}->{$_}->{'type'}}, 'exon2';
    }   
  }   
  
  $markup->{'exons'}->{0}->{'type'} = [ 'exon0' ];
}

1;
