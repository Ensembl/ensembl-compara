# $Id$

package EnsEMBL::Web::ViewConfig::Location::ViewTop;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    show_panel => 'yes'
  });
  
  $self->add_image_config('contigviewtop', 'nodas');
  $self->title = 'Overview Image';
}

sub form {
  my $self = shift;
  $self->add_form_element({ type => 'YesNo', name => 'show_panel', select => 'select', label => 'Show panel' });
}

1;
