package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;

use URI::Escape qw(uri_escape);
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'logins' => '?' ); }

sub logins      :lvalue { $_[0]{'logins'}; }
sub blast       :lvalue { $_[0]{'blast'}; }
sub biomart     :lvalue { $_[0]{'biomart'}; }
sub mirror_icon :lvalue { $_[0]{'mirror_icon'}; }

sub render {
  my $self = shift;
  
  my $species_defs = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
  my $dir = $species_defs->species_path;
  $dir = '' if $dir !~ /_/;
  
  my $html = '<div class="print_hide">';

  my $blast_dir;
  my $sp_dir = $ENV{'ENSEMBL_SPECIES'};
  
  if (!$sp_dir || $sp_dir eq 'Multi' || $sp_dir eq 'common') {
    $blast_dir = 'Multi';
  } else {
    $blast_dir = $sp_dir;
  }
  
  if ($self->logins) {
    if ($ENV{'ENSEMBL_USER_ID'}) {
      $html .= qq{
        <a style="display:none" href="$dir/Account/Links" class="modal_link">Account</a> &nbsp;|&nbsp;
        <a href="$dir/Account/Logout">Logout</a> &nbsp;|&nbsp;
      };
    } else {
      $html .= qq{
        <a style="display:none" href="$dir/Account/Login" class="modal_link">Login</a> / 
        <a style="display:none" href="$dir/Account/User/Add" class="modal_link">Register</a> &nbsp;|&nbsp;
      };
    }
  }
  
  $html .= qq{<a href="/$blast_dir/blastview">BLAST/BLAT</a> &nbsp;|&nbsp;} if $self->blast;
  $html .= qq{<a href="/biomart/martview">BioMart</a> &nbsp;|&nbsp;}        if $self->biomart;
  $html .= qq{<a href="/info/website/help/" id="help">Docs &amp; FAQs</a>};
  $html .= '</div>';
  
  $self->print($html);
}

1;

