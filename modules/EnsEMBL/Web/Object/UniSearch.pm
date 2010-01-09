package EnsEMBL::Web::Object::UniSearch;

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

sub caption       { return undef; }
sub short_caption { return 'Search'; }
sub counts        { return undef; }


1;
