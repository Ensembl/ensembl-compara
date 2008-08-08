package EnsEMBL::Web::ImageConfig::chromosome;

use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->set_title( 'Chromosome' );

  $self->create_menus(
    'decorations' => 'Chromosome',
  );

## Load all tracks from the database....
#  $self->load_tracks();

## Now we have a number of tracks which we have to manually add...
  $self->add_tracks( 'decorations' => [qw(ideogram assembly_exception)] );
  $self->configurable( 0 );
  
  $self->set_options({
    'show_buttons'        => { 'value' => 0 },
    'show_labels'         => { 'value' => 1 }
  });
}
1;
