# $Id$

package EnsEMBL::Web::ViewConfig::GeneTree::Image;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Gene::Compara_Tree);

sub form { 
  my $self = shift;
  
  $self->SUPER::form;
  
  my $fieldset = $self->get_fieldset(0);
  
  $_->remove for grep scalar @{$_->get_elements_by_name('collapsability')}, @{$fieldset->fields};
}

1;
