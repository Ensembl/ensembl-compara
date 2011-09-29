# $Id$

package EnsEMBL::Web::ViewConfig::Location::MultiTop;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->set_defaults({
    show_top_panel => 'yes'
  });
  
  $self->add_image_config('MultiTop', 'nodas');
  $self->title = 'Overview Image';
}

sub form {
  my $self = shift;
  $self->add_form_element({ type => 'YesNo', name => 'show_panel', select => 'select', label => 'Show panel' });
}

1;
