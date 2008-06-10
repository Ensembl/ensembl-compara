package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'logins' => '?' ); }

sub logins    :lvalue { $_[0]{'logins'};   }

sub render   {
  my $self = shift;
  my $species = $ENV{'ENSEMBL_SPECIES'} || 'default';
  my $html = qq(
  );
  if ($self->logins) {
    if ($ENV{'ENSEMBL_USER_ID'}) {
      $html .= qq(
      <a href="/Account/Summary">Control Panel</a> &nbsp;|&nbsp;
      <a href="javascript:logout_link();">Logout</a> &nbsp;|&nbsp;
      );
    }
    else {
      $html .= qq(
      <a href="/Account/Login">Control Panel</a> &nbsp;|&nbsp;
      <a href="javascript:login_link();">Login</a> / <a href="/Account/Register">Register</a> &nbsp;|&nbsp;
      );
    }
  }
  $html .= qq(
      <a href="$species/Blast">BLAST</a> &nbsp;|&nbsp; 
      <a href="$species/Biomart">BioMart</a> &nbsp;|&nbsp;
      <a href="/info/website/help/" id="help"><img src="/i/e-quest_bg.gif" alt="e?" style="vertical-align:middle" />&nbsp;Help</a>);
  $self->printf($html);
}

1;

