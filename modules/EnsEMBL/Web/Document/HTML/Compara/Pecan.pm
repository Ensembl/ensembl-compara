package EnsEMBL::Web::Document::HTML::Compara::Pecan;

## Provides content for compara documeentation - see /info/docs/compara/analyses.html

use strict;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render {
  my $self = shift;

  my $sets = [{'name' => 'amniotes', 'label' => 'amniota vertebrates'}];

  return $self->format_list('PECAN', $sets);
}

1;
