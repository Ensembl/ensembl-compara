package EnsEMBL::Web::Document::HTML::DocsMenu;

### Generates "local context" menu for documentation (/info/)

use strict;
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;

## TO DO - make this dynamic, using web tree!

  return( q(<dl id="local">
<dd class="closed"><a href="/info/website/">Using this website</a></dd>    
<dd class="closed"><a href="/info/data/">Fetching data</a></dd>    
<dd class="closed"><a href="/info/docs/">Code documentation</a></dd>    
<dd class="closed"><a href="/info/about/">About us</a></dd>    
</dl>) );
}

1;
