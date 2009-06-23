package EnsEMBL::Web::ImageConfig::idhistoryview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_; 
  $self->set_parameters({
    'title'         => 'ID History Map',
    'show_buttons'  => 'no',   # show +/- buttons
    'button_width'  => 8,       # width of red "+/-" buttons
    'show_labels'   => 'no',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,       # margin
    'spacing'       => 2,       # spacing
  });

  $self->create_menus(
    'ID_History'      => 'History',
  );

  ## Add in additional
   $self->load_tracks();

  $self->add_tracks('ID_History',
  ['idhistorytree',   '',   'idhistorytree', { 'on' => 'on',   'strand' => 'f'} ]
  );
}
1;
