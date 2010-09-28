# $Id$

package EnsEMBL::Web::Controller::ZMenu;

### Prints the popup zmenus on the images.

use strict;

use SiteDefs;

use base qw(EnsEMBL::Web::Controller);

sub init {
  my $self = shift;
  
  $self->builder->create_objects;
  $self->build_menu;
}

sub build_menu {
  ### Creates a ZMenu module based on the object type and action of the page (see below), and renders the menu
  
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
 
  # Force values of action and type because apparently require "EnsEMBL::Web::ZMenu::::Gene" (for eg) doesn't fail. Stupid perl.
  my $type   = $self->type   || 'NO_TYPE';
  my $action = $self->action || 'NO_ACTION';
  my $menu;
  
  my $i;
  my @packages = (map({ ++$i % 2 ? $_ : () } @$ENSEMBL_PLUGINS), 'EnsEMBL::Web');
  
  ### Check for all possible module permutations.
  ### This way we can have, for example, ZMenu::Contig and ZMenu::Contig::Gene (contig menu with Gene page specific functionality),
  ### and also ZMenu::Gene and ZMenu::Gene::ComparaTree (has a similar menu to that of a gene, but has a different glyph in the drawing code)
  my @modules = (
    "::ZMenu::$type",
    "::ZMenu::$action",
    "::ZMenu::${type}::$action",
    "::ZMenu::${action}::$type"
  );
  
  foreach my $module_root (@packages) {
    my $module_name = [ map { $self->dynamic_use("$module_root$_") ? "$module_root$_" : () } @modules ]->[-1];
    
    if ($module_name) {
      $menu = $module_name->new($hub, $object, $menu);
      
      last;
    } else {
      my $error = $self->dynamic_use_failure("$module_root$modules[-1]");
      warn $error unless $error =~ /^Can't locate/;
    }
  }
  
  $self->r->content_type('text/plain');
  
  $menu->render if $menu;
}

1;
