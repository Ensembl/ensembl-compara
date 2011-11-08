# $Id$

package EnsEMBL::Web::Configuration::UserConfig;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'ManageConfigs';
}

sub populate_tree {
  my $self = shift;
  
  ## Configuration management
  $self->create_node('ManageConfigs', 'Manage configurations',
    [ 'manage_config', 'EnsEMBL::Web::Component::UserConfig::ManageConfigs' ],
    { availability => 1 }
  );
  
  $self->create_node('ManageSets', 'Manage sets',
    [ 'manage_sets', 'EnsEMBL::Web::Component::UserConfig::ManageSets' ],
    { availability => 1 }
  );
  
  $self->create_node('ModifyConfig', '',
    [],
    { command => 'EnsEMBL::Web::Command::UserConfig::ModifyConfig', no_menu_entry => 1 }
  );
}

1;
