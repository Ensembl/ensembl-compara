package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;
use EnsEMBL::Web::Document::HTML;
use CGI qw(escape);

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'logins' => '?' ); }

sub logins    :lvalue { $_[0]{'logins'};   }
sub referer   :lvalue { $_[0]{'referer'};   } ## Needed by CloseCP

sub render   {
  my $self = shift;
  my $species = $ENV{'ENSEMBL_SPECIES'} || 'default';
  my $url = $ENV{'SCRIPT_NAME'};
  if ($ENV{'QUERY_STRING'}) {
    $url .= '?'.$ENV{'QUERY_STRING'};
  }
  my $html;
  if ($self->logins) {
    if ($ENV{'ENSEMBL_USER_ID'}) {
      $html .= qq(
      <a href="/Account/Links?_referer=$url" class="modal_link">Control Panel</a> &nbsp;|&nbsp;
      <a href="/Account/Logout?_referer=$url" class="modal_link">Logout</a> &nbsp;|&nbsp;
      );
    }
    else {
      $html .= qq(
      <a href="/UserData/Upload?_referer=$url" class="modal_link">Control Panel</a> &nbsp;|&nbsp;
      <a href="/Account/Login?_referer=$url" class="modal_link">Login</a> / 
      <a href="/Account/Register?_referer=$url" class="modal_link">Register</a> &nbsp;|&nbsp;
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

