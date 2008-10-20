package EnsEMBL::Web::ViewConfig::Gene::Family;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  our %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $view_config->_set_defaults(
    map( { 'species_'.lc($_) => 'yes' } @{$view_config->species_defs->ENSEMBL_SPECIES} ), 
    map( { 'opt_'.lc($_) => 'yes' } keys %formats )

  );
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;
  our %formats = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;

  $view_config->add_fieldset('Show genes from the following species');
  foreach( @{$view_config->species_defs->ENSEMBL_SPECIES} ) {
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $view_config->_species_label($_),
      'name'     => 'species_'.lc($_),
      'value'    => 'yes', 'raw' => 1
    });
  }
  $view_config->add_fieldset('Show genes from the following databases');
  foreach( sort keys %formats ) {
    $view_config->add_form_element({
      'type'     => 'CheckBox', 'label' => $formats{$_}{'name'},
      'name'     => 'opt_'.lc($_),
      'value'    => 'yes', 'raw' => 1
    });

  }
}

1;
