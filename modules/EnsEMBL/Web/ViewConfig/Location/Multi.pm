package EnsEMBL::Web::ViewConfig::Location::Multi;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $view_config = shift;

  $view_config->_set_defaults(qw(
    show_panels  both
    panel_zoom   no
    zoom_width   100
    context      1000
  ));
  
  $view_config->add_image_configs({qw(
    MultiTop     nodas
    MultiBottom  nodas
  )});
  
  $view_config->default_config = 'MultiBottom';
  $view_config->storable = 1;
}

sub form {
  my $view_config = shift;
  
  $view_config->default_config = 'MultiTop' if $view_config->get('show_panels') eq 'top';
  
  $view_config->add_form_element({ 
    type   => 'DropDown', 
    name   => 'show_panels', 
    select => 'select', 
    label  => 'Displayed panel',
    values   => [{
      value => 'both',
      name  => 'Both panels'
    }, {
      value => 'bottom',
      name  => 'Main panel only'
    }, {
      value => 'top',
      name  => 'Top panel only'
    }]
  });
}

1;
