package EnsEMBL::Web::ViewConfig::Variation::Context;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_genotypes  on
    panel_alleles    on
    panel_locations  on
    panel_individual off
    image_width      900
    context          30000
  ));
  
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $view_config->_set_defaults(lc($key) => $hash{$key}[0]);
    }
  }
  
  $view_config->add_image_configs({ snpview => 'nodas' });

  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;
  $view_config->default_config = 'snpview'; 

  # Add context selection
  $view_config->add_fieldset('Context');
  $view_config->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '1000',  name => '1kb' },
      { value => '5000',  name => '5kb' },
      { value => '10000', name => '10kb' },
      { value => '20000', name => '20kb' },
      { value => '30000', name => '30kb' }
    ]
  });
}
1;
