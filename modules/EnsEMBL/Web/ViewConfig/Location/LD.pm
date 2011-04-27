# $Id$

package EnsEMBL::Web::ViewConfig::Location::LD;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    context 10000
  ));

 ## Add other options
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS;

  foreach (keys %options){
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $self->_set_defaults(lc $key => $hash{$key}[0]);
    }
  }
  
  $self->add_image_configs({qw(
    ldview nodas
  )});
  
  $self->default_config = 'ldview';
  $self->storable       = 1;
}

1;
