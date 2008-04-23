package EnsEMBL::Web::Document::HTML::StaticLocalContext;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  $self->printf( q(<dl id="local">
<dd class="closed"><a href="/info/website/">Using this website</a></dd>    
<dd class="closed"><a href="/info/data/">Fetching data</a></dd>    
<dd class="closed"><a href="/info/docs/">Documentation</a></dd>    
<dd class="closed"><a href="/info/about/">About us</a></dd>    
</dl>) );
}

return 1;
