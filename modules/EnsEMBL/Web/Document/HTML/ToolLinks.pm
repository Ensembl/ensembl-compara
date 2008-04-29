package EnsEMBL::Web::Document::HTML::ToolLinks;
use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $species = $ENV{'ENSEMBL_SPECIES'} || 'default';
  my ($user, $html);
  if ($ENV{'ENSEMBL_LOGINS'} && $user) {
    $html .= qq(<a href="/User" class="modal_link">Your Account</a>
      );
  }
  else {
    $html .= qq(<a href="/User/Login" class="modal_link">Login</a> / <a href="/User/Register" class="modal_link">Register</a>
      );
  }
  $html .= qq( &nbsp;|&nbsp;
      <a href="/Configurator" class="modal_link">Control Panel</a> &nbsp;|&nbsp;
      <a href="$species/Blast">BLAST</a> &nbsp;|&nbsp; 
      <a href="$species/Biomart">BioMart</a> &nbsp;|&nbsp;
      <a href="/info/">Documentation</a> &nbsp;|&nbsp;
      <a href="/info/website/help/" id="help"><img src="/i/e-quest_bg.gif" alt="e?" style="vertical-align:middle" />&nbsp;Help</a>
      );
  $_[0]->printf($html);
}

1;

