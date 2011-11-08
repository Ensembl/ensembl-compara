package EnsEMBL::Web::Data::Record::FavouriteTracks;

use strict;

use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->set_type('favourite_tracks');

__PACKAGE__->add_fields(
  tracks => 'text'
);

1;