package EnsEMBL::Web::TextSequence::Annotation::FocusVariant;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $sl, $mk, $seq) = @_;

  foreach (@{$config->{'focus_position'} || []}) {
    $mk->{'variants'}{$_}{'align'} = 1;
    # XXX naughty messing with other's markup
    delete $mk->{'variants'}{$_}{'href'} if $sl->{'main_slice'}; # delete link on the focus variation on the primary species, since we're already looking at it
  }
}

1;
