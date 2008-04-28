package EnsEMBL::Web::Document::HTML::ToolLinks;
use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $species = $ENV{'ENSEMBL_SPECIES'} || 'default';
  my $html = qq(
      <a href="$species/Blast">BLAST</a> &nbsp;|&nbsp; 
      <a href="$species/Biomart">BioMart</a> &nbsp;|&nbsp;
      <a href="/info/">Documentation</a> &nbsp;|&nbsp;
      <a href="/info/website/help/" id="help"><img src="/i/e-quest_bg.gif" alt="e?" style="vertical-align:middle" />&nbsp;Help</a> &nbsp;|&nbsp;
      <a href="/Configurator">Control Panel</a> &nbsp;|&nbsp;
      );
  my $user;
  if ($ENV{'ENSEMBL_LOGINS'} && $user) {
    $html .= qq(<a href="/User">Your Account</a>
      );
  }
  else {
    $html .= qq(<a href="/">Login</a> &middot; <a href="/">Register</a>
      );
  }
  $_[0]->printf($html);
}

=pod
=cut

1;

