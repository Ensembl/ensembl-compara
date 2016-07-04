package EnsEMBL::Web::TextSequence::Sequence::Transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Sequence);

sub fixup_markup {
  my ($self,$markup,$config) = @_;

  # Maintain exon classes across letters
  my @classes = split(' ',$markup->{'class'}||'');
  my ($new_exon) = grep { /^e\w$/ } @classes;
  if($new_exon) {
    $self->{'cur_exon'} = $new_exon;   # ... set
  } elsif(!$markup->{'tag'}) {
    push @classes,$self->{'cur_exon'}; # ... use
  }
  $markup->{'class'} = join(' ',@classes);
}

1;
