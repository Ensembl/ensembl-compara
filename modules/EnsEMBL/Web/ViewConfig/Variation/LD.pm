# $Id$

package EnsEMBL::Web::ViewConfig::ldview;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    panel_options    on
    panel_image      on
    image_width      800
    context          10000
  ));
  
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $self->_set_defaults(lc $key => $hash{$key}[0]);
    }
  }
  
  $self->add_image_configs({qw(
    ldview        nodas
    LD_population nodas
  )});
  
  $self->storable = 1;

}

1;
