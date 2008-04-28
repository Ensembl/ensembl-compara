package EnsEMBL::Web::Document::HTML::DocsMenu;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  return( q(<dl id="local">
<dd class="closed"><a href="/info/website/">Using this website</a></dd>    
<dd class="closed"><a href="/info/data/">Fetching data</a></dd>    
<dd class="closed"><a href="/info/docs/">Code documentation</a></dd>    
<dd class="closed"><a href="/info/about/">About us</a></dd>    
</dl>) );
}

1;
