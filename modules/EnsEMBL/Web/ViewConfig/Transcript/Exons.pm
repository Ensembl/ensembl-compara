package EnsEMBL::Web::ViewConfig::Transcript::Exons;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_exons      on
    panel_supporting on
    sscon            25
    flanking         50
    fullseq          no
    oexon            no
  ));
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $obj ) = @_;

  $view_config->add_form_element({
    'type' => 'NonNegInt',
    'required' => 'no',
    'label' => "Flanking sequence at either end of transcript",
    'name' => 'flanking',
  });
  $view_config->add_form_element({
    'type' => 'CheckBox',
    'label' => "Show full intronic sequence",  'name' => 'fullseq',
    'value' => 'yes'
  });
  $view_config->add_form_element({
    'type' => 'CheckBox',
    'label' => "Show exons only",  'name' => 'oexon',
    'value' => 'yes',
  });

}
1;
