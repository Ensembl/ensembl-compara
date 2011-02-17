# $Id$

package EnsEMBL::Web::Document::Element::ModalButtons;

# Generates the tools buttons below the control panel left menu - add track, reset configuration

use strict;

use base qw(EnsEMBL::Web::Document::Element::ToolButtons);

sub label_classes {
  return {
    'Add custom track'    => 'data',
    'Reset configuration' => 'config'
  };
}

sub init {
  my $self       = shift;  
  my $controller = shift;
  my $hub        = $controller->hub;
  
  if ($hub->script eq 'Config') {
    my $config = $hub->param('config');
    
    $self->add_entry({
      caption => 'Add custom track',
      class   => 'modal_link',
      url     => $hub->url({
        type    => 'UserData',
        action  => 'SelectFile',
        __clear => 1 
      })
    });

    $self->add_entry({
      caption => 'Reset configuration',
      class   => 'modal_link',
      url     => $hub->url('Config', {
        reset   => 1,
        config  => $config eq '_page' ? '' : $config,
        __clear => 1 
      })
    });
  }
}

1;
