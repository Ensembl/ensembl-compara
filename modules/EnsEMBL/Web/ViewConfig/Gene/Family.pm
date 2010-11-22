package EnsEMBL::Web::ViewConfig::Gene::Family;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config) = @_;
  
  my %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $view_config->_set_defaults(
    map({ 'species_'. lc($_) => 'yes' } $view_config->species_defs->valid_species),
    map({ 'opt_'. lc($_) => 'yes' } keys %formats)
  );
  
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;
  my $species_defs = $view_config->species_defs;

  $view_config->add_fieldset('Selected species');
  
  foreach ($species_defs->valid_species) {
    $view_config->add_form_element({
      'type'  => 'CheckBox', 
      'label' => $species_defs->species_label($_),
      'name'  => 'species_' . lc($_),
      'value' => 'yes', 
      'raw'   => 1
    });
  }
  $view_config->add_fieldset('Selected databases');
  
  foreach(sort keys %formats) {
    $view_config->add_form_element({
      'type'  => 'CheckBox', 
      'label' => $formats{$_}{'name'},
      'name'  => 'opt_' . lc($_),
      'value' => 'yes', 
      'raw'   => 1
    });
  }
}

1;
