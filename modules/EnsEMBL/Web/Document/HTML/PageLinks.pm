package EnsEMBL::Web::Document::HTML::PageLinks;
use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  $_[0]->printf(q(
      <a href="%s/Blast">BLAST</a> | 
      <a href="%s/Biomart">BioMart</a> &nbsp;|&nbsp;
      <a href="/common/user/login" id="login"    class="modal_link">Login</a> | 
      <a href="/common/user/register" id="register" class="modal_link">Register</a> &nbsp;|&nbsp;
      <a href="%s">Home</a> |
      <a href="/sitemap.html" id="sitemap" class="modal_link">Site map</a> |
      <a href="/default/helpview" id="help" class="modal_link"><span>e<span>?</span></span>Help</a>
    ), '/Homo_sapiens', '/Homo_sapiens', '/'
  );
}

1;

