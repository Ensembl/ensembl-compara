package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;
use EnsEMBL::Web::Document::HTML;
use CGI qw(escape);

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'logins' => '?' ); }

sub logins    :lvalue { $_[0]{'logins'};   }
sub blast     :lvalue { $_[0]{'blast'};   }
sub biomart   :lvalue { $_[0]{'biomart'};   }
sub referer   :lvalue { $_[0]{'referer'};   } ## Needed by CloseCP

sub render   {
  my $self    = shift;
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $url     = CGI::escape($ENV{'REQUEST_URI'});
  my $html = '<div class="print_hide">';
  
  if( $self->logins ) {
    if( $ENV{'ENSEMBL_USER_ID'} ) {
      $html .= qq(
      <a style="display:none" href="$dir/Account/Links?_referer=$url" class="modal_link">Account</a> &nbsp;|&nbsp;
      <a href="$dir/Account/Logout?_referer=$url">Logout</a> &nbsp;|&nbsp;
      );
    } else {
      $html .= qq(
      <a style="display:none" href="$dir/Account/Login?_referer=$url" class="modal_link">Login</a> / 
      <a style="display:none" href="$dir/Account/User/Add?_referer=$url" class="modal_link">Register</a> &nbsp;|&nbsp;
      );
    }
  }
  $html .= qq(<a href="/Multi/blastview">BLAST/BLAT</a> &nbsp;|&nbsp;) if $self->blast;
  $html .= qq(<a href="/biomart/martview">BioMart</a> &nbsp;|&nbsp;)   if $self->biomart;
  $html .= qq(<a href="/info/website/help/" id="help">Docs &amp; FAQs</a>);
  $html .= '</div>';

  $self->print($html);
}

1;

