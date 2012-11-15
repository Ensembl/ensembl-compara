package EnsEMBL::Web::Document::HTML::Compara::EPOlc;

## Provides content for compara documeentation - see /info/docs/compara/analyses.html

use strict;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render {
  my $self = shift;

  my $sets = [{'name' => 'mammals', 'label' => 'eutherian mammals'}];

  return $self->format_list('EPO_LOW_COVERAGE', $sets);
}

1;
