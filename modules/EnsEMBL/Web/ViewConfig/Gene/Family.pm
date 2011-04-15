# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Family;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self    = shift;
  my %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $self->_set_defaults(
    map({ 'species_'. lc($_) => 'yes' } $self->species_defs->valid_species),
    map({ 'opt_'. lc($_) => 'yes' } keys %formats)
  );
  
  $self->storable = 1;
  $self->nav_tree = 1;
}

sub form {
  my $self         = shift;
  my %formats      = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;
  my $species_defs = $self->species_defs;

  $self->add_fieldset('Selected species');
  
  foreach ($species_defs->valid_species) {
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $species_defs->species_label($_),
      name  => 'species_' . lc $_,
      value => 'yes', 
      raw   => 1
    });
  }
  $self->add_fieldset('Selected databases');
  
  foreach(sort keys %formats) {
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $formats{$_}{'name'},
      name  => 'opt_' . lc $_,
      value => 'yes', 
      raw   => 1
    });
  }
}

1;
