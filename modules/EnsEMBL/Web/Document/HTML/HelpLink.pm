package EnsEMBL::Web::Document::HTML::HelpLink;
use strict;
use CGI qw(escapeHTML escape);
use EnsEMBL::Web::Document::HTML;

use constant HELPVIEW_WIN_ATTRIBS => "width=700,height=550,resizable,scrollbars,toolbar";

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new           {
  return shift->SUPER::new(
    'kw'    => undef,
    'label' => 'Help',
    'URL'   => "/common/helpview" 
  ); 
}
sub URL    :lvalue { $_[0]{'URL'};   }
sub kw     :lvalue { $_[0]{'kw'};    }
sub ref    :lvalue { $_[0]{'ref'};   }
sub action :lvalue { $_[0]{'action'};   }
sub label  :lvalue { $_[0]{'label'};    }
sub simple :lvalue { $_[0]{'simple'}; }

sub render {
  my $self = shift;

  my $help_link;
    my $extra_HTML = join ";",
      $self->kw     ? "kw=@{[$self->kw]}" : (),
      $self->ref    ? "ref=@{[CGI::escape($self->ref)]}" : (),
      $self->action ? "action=@{[$self->action]}" : ();
    my $URL = $self->URL.($extra_HTML?"?$extra_HTML":"");
    if( $self->action ) { ## ALREADY IN HELP FORM!!
      $help_link = qq(<a href="$URL" class="blue-button">@{[$self->label]}</a>);
    } else {
      $help_link = sprintf( q(<a href="javascript:void(window.open('%s','helpview','%s'))" class="blue-button">%s</a>),
        $URL, HELPVIEW_WIN_ATTRIBS, uc($self->label)
      );
    }
  
  ## Set directories 
  my ($map_link, $blast_dir);
  my $sp_dir = $ENV{'ENSEMBL_SPECIES'};
  if (!$sp_dir || $sp_dir eq 'Multi' || $sp_dir eq 'common') {
    $map_link = 'sitemap.html';
    $blast_dir = 'Multi';
  }
  else {
    $map_link = $sp_dir . '/sitemap.html';
    $blast_dir = $sp_dir;
  }

  ## Assemble links
  my $html;
  unless ($self->simple) {
    $html .= qq(<a href="/">HOME</a> &middot; <a href="/$blast_dir/blastview">BLAST</a>);
    if ($ENV{'ENSEMBL_MART_ENABLED'}) {
      $html .= qq( &middot; <a href="/biomart/martview/">BIOMART</a>);
    }
    $html .= qq( &middot; <a href="/$map_link">SITEMAP</a> );
  }
  $html .= $help_link;

  $self->print( qq(
<div id="help"><strong>$html</strong></div>));
}

1;

