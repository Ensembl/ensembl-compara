package EnsEMBL::Web::Document::HTML::Empty;
use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

### Allows easy removal of items from template

sub render {
  return;
}

1;
