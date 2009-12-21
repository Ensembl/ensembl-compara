package EnsEMBL::Web::Document::HTML::Empty;

### Allows easy removal of items from template

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

## Stubs for functions called by modules that are being replaced
sub logins      :lvalue { $_[0]{'logins'};  }
sub sitename    :lvalue { $_[0]{'sitename'};   }

sub render { return; }

1;
