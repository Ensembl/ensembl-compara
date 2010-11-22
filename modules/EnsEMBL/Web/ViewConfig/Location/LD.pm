package EnsEMBL::Web::ViewConfig::Location::LD;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config ) = @_;

  $view_config->_set_defaults(qw(
    context        10000
  ));

 ## Add other options
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS;

  foreach (keys %options){
    my %hash = %{$options{$_}};
    foreach my $key (keys %hash){
     $view_config->_set_defaults(lc($key) =>  $hash{$key}[0]);
    }
  }

   
  $view_config->add_image_configs({qw(
    ldview  nodas
    ld_population nodas
  )});
  $view_config->default_config = 'ldview';
  $view_config->storable = 1;
}

1;
