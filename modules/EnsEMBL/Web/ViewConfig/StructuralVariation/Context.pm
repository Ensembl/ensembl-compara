# $Id$

package EnsEMBL::Web::ViewConfig::StructuralVariation::Context;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    panel_genotypes  on
    panel_alleles    on
    panel_locations  on
    panel_individual off
    image_width      900
    context          20000
  ));
  
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $self->_set_defaults(lc $key => $hash{$key}[0]);
    }
  }
	
  $self->add_image_configs({ structural_variation => 'nodas' });
  $self->storable = 1;
}

sub form {
  my $self = shift;
	
  $self->default_config = 'structural_variation'; 

  # Add context selection
	$self->add_fieldset('Context');
  
  $self->add_form_element({
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
