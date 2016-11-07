package EnsEMBL::Web::TextSequence::Markup::Conservation;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config) = @_; 

  my $cons_threshold = int((scalar(@$sequence) + 1) / 2); # Regions where more than 50% of bps match considered "conserved"
  my $conserved      = 0;
  
  for my $i (0..$config->{'length'} - 1) {
    my %cons;
    $cons{$_->legacy->[$i]{'letter'}}++ for @$sequence;

    my $c = join '', grep { $_ !~ /~|[-.N]/ && $cons{$_} > $cons_threshold } keys %cons;
       
    foreach (@$sequence) {
      next unless $_->legacy->[$i]{'letter'} eq $c; 
    
      $_->legacy->[$i]{'class'} .= 'con ';
      $conserved = 1;
    }   
  }
  
  $config->{'key'}{'other'}{'conservation'} = 1 if $conserved;
}

1;
