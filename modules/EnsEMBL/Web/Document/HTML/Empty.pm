package EnsEMBL::Web::Document::HTML::Empty;

### Allows easy removal of items from template

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  return;
}

1;
