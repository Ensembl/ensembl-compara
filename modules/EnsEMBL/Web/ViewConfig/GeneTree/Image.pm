package EnsEMBL::Web::ViewConfig::GeneTree::Image;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Gene::Compara_Tree);

sub form { 
  my ($view_config, $object) = @_;
  $view_config->SUPER::form($object);
  my $fieldset = $view_config->get_fieldset(0);
  scalar @{$_->get_elements_by_name('collapsability')} and $_->remove() for @{$fieldset->fields};
}

1;
