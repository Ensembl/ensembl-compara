package EnsEMBL::Web::Object::Search;

### NAME: EnsEMBL::Web::Object::Search
### An empty wrapper object, used by search results pages 

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Has no data access functionality, just page settings

### DESCRIPTION


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
