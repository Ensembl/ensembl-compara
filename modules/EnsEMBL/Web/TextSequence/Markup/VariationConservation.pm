package EnsEMBL::Web::TextSequence::Markup::VariationConservation;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup::Conservation);

sub replaces { return 'EnsEMBL::Web::TextSequence::Markup::Conservation'; }

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  my $difference = 0;
 
  for my $i (0..scalar(@$sequence)-1) {
    # XXX temporary hack for Compara_Alignments
   next unless $sequence->[$i]->is_root;

    next if $config->{'slices'}->[$i] and $config->{'slices'}->[$i]->{'no_alignment'};
    
    my $seq = $sequence->[$i]->legacy;
   
    for (0..$config->{'length'}-1) {
      next if $seq->[$_]->{'match'};
    
      $seq->[$_]->{'class'} .= 'dif ';
      $difference = 1;
    }   
  }
  
  $config->{'key'}->{'other'}{'difference'} = 1 if $difference;
}

1;
