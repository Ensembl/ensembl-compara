package EnsEMBL::Web::Document::HTML::IEHoverHack;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::IEHoverHack::ISA = qw(EnsEMBL::Web::Document::HTML);

sub render { 
  $_[0]->print( qq(<!--[if IE]>
<style type="text/css" media="screen">
  body { behavior: url(/css/csshover.htc); } /* enable IE to resize em fonts */
</style>
<![endif]-->
));
}

1;
