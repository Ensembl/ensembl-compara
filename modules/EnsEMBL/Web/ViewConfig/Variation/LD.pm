package EnsEMBL::Web::ViewConfig::ldview;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_options    on
    panel_image      on
    image_width      800
    context          10000
  ));
  
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $view_config->_set_defaults(lc($key) => $hash{$key}[0]);
    }
  }
  
  $view_config->add_image_configs({qw(
    ldview        nodas
    LD_population nodas
  )});
  
  $view_config->storable = 1;

}

sub form {}

1;
