package EnsEMBL::Web::Document::HTML::LocalContext;

### Generates the global context navigation menu, used in dynamic pages

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  $self->printf( q(<dl id="local" class="ajax" title="['/Homo_sapiens/ajax-menu/2']"></dl></div>) );
}

return 1;
