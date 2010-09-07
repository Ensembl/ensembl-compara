package EnsEMBL::Web::Object::Search;

### NAME: EnsEMBL::Web::Object::Search
### An empty wrapper object, used by search results pages 

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Has no data access functionality, just page settings

### DESCRIPTION


use strict;

use base qw(EnsEMBL::Web::Object);

sub default_action { return 'New'; }
sub short_caption  { my $sitetype = $_[0]->species_defs->ENSEMBL_SITETYPE || 'Ensembl'; return $_[1] eq 'global' ? 'New Search' : "Search $sitetype"; }
sub caption        { my $sitetype = $_[0]->species_defs->ENSEMBL_SITETYPE || 'Ensembl'; return "$sitetype text search"; }
sub counts         {}

1;
