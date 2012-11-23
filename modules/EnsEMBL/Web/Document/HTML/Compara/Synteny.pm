package EnsEMBL::Web::Document::HTML::Compara::Synteny;

use strict;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render { 
  my $self = shift;

  return $self->draw_stepped_table('SYNTENY');
}

1;
