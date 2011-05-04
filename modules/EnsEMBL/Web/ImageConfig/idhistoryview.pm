# $Id$

package EnsEMBL::Web::ImageConfig::idhistoryview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title       => 'ID History Map',
    show_labels => 'no',   # show track names on left-hand side
    label_width => 100,    # width of labels on left-hand side
  });

  $self->create_menus(
    ID_History => 'History',
  );

  $self->load_tracks;

  $self->add_tracks('ID_History',
    [ 'idhistorytree', '', 'idhistorytree', { display => 'on', strand => 'f', menu => 'no' }]
  );
}

1;
