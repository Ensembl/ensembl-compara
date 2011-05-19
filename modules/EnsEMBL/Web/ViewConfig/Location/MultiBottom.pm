# $Id$

package EnsEMBL::Web::ViewConfig::Location::MultiBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->set_defaults({
    show_bottom_panel => 'yes'
  });
  
  $self->add_image_config('MultiBottom', 'nodas');
  $self->title = 'Multi-species Image';
}

sub form {
  my $self = shift;
  $self->add_form_element({ type => 'YesNo', name => 'show_bottom_panel', select => 'select', label => 'Show panel' });
}

1;
