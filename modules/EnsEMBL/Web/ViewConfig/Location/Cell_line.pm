package EnsEMBL::Web::ViewConfig::Location::Cell_line;

use EnsEMBL::Web::ViewConfig::Cell_line qw(form init);

use strict;

sub init {
  EnsEMBL::Web::ViewConfig::Cell_line::init(@_);
  $_[0]->has_images = 0;
}

1;
