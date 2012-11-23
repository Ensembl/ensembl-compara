package EnsEMBL::Web::Document::HTML::Compara::TBlat;

use strict;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render { 
  my $self = shift;

  return $self->draw_stepped_table('TRANSLATED_BLAT_NET'); 
}

1;
