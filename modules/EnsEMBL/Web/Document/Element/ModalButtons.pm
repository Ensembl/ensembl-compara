# $Id$

package EnsEMBL::Web::Document::Element::ModalButtons;

# Generates the tools buttons below the control panel left menu - add track, reset configuration

use strict;

use base qw(EnsEMBL::Web::Document::Element::ToolButtons);

sub label_classes {
  return {
    'Add custom track'    => 'data',
    'Reset configuration' => 'config',
    'Reset track order'   => 'config'
  };
}

sub init {
  my $self       = shift;  
  my $controller = shift;
  my $hub        = $controller->hub;
  
  if ($hub->script eq 'Config') {
    my $config       = $hub->param('config');
    my $image_config = $hub->get_imageconfig($config);
    my $rel          = "modal_config_$config";
       $rel         .= '_' . lc $hub->species if $image_config && $image_config->multi_species && $hub->referer->{'ENSEMBL_SPECIES'} ne $hub->species;
       $rel          =~ s/__/_/; # config paramenter can be _page, so in this case make sure we have the correct value

    $self->add_entry({
      caption => 'Reset configuration',
      class   => 'modal_link',
      rel     => $rel,
      url     => $hub->url('Config', {
        config => $config,
        reset  => 1
      })
    });
    
    if ($image_config) {
      if ($image_config->get_parameter('sortable_tracks')) {
        $self->add_entry({
          caption => 'Reset track order',
          class   => 'modal_link',
          rel     => $rel,
          url     => $hub->url('Config', {
            reset   => 'track_order',
            config  => $config,
            __clear => 1 
          })
        });
      }
      
      $self->add_entry({
        caption => 'Add custom track',
        class   => 'modal_link',
        url     => $hub->url({
          type    => 'UserData',
          action  => 'SelectFile',
          __clear => 1 
        })
      });
    }
  }
}

1;
