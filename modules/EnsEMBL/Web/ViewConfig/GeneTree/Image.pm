package EnsEMBL::Web::ViewConfig::GeneTree::Image;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::ViewConfig::Gene::Compara_Tree;

sub init { return EnsEMBL::Web::ViewConfig::Gene::Compara_Tree::init(@_); }

sub form { 
  my( $view_config, $object ) = @_;
  EnsEMBL::Web::ViewConfig::Gene::Compara_Tree::form($view_config, $object);
  my $fieldset = $view_config->get_fieldset(0);
  $fieldset->delete_element('collapsability');
}

1;
