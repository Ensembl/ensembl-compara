package EnsEMBL::Web::ViewConfig::Variation::Summary;

use strict;

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    flank_size          400
    show_mismatches     yes
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  # Add selection
  $view_config->add_fieldset('Flanking sequence');
  
  $view_config->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Length of reference flanking sequence to display',
    name   => 'flank_size',
    values => [
      { value => '100',  name => '100bp' },
      { value => '200',  name => '200bp' },
      { value => '300', name => '300bp' },
      { value => '400', name => '400bp' },
      { value => '500', name => '500bp' },
      { value => '500', name => '500bp' },
      { value => '1000', name => '1000bp' },
    ]
  });
  
  $view_config->add_form_element({
    type  => 'CheckBox',
    label => 'Highlight differences between source and reference flanking sequences',
    name  => 'show_mismatches',
    value => 'yes',
    raw   => 1,
  });
}
1;
