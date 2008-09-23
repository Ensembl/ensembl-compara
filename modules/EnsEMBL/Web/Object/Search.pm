package EnsEMBL::Web::Object::Search;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

sub short_caption {
  my $self = shift;
  return 'Search Ensembl';
}

sub caption {
    my $self = shift;
    my $caption = 'Ensembl text search';
    return $caption;
}

sub counts {
    my $self = shift;
    return;
}


1;
