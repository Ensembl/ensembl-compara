package EnsEMBL::Web::ZMenu::ComparaTreeNode_pan_compara;

use strict;

use base qw(EnsEMBL::Web::ZMenu::ComparaTreeNode);

sub content {
  my $self = shift;
  return $self->SUPER::content('compara_pan_ensembl');
}

1;
