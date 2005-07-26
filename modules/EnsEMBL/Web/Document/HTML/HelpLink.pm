package EnsEMBL::Web::Document::HTML::HelpLink;
use strict;
use CGI qw(escapeHTML escape);
use EnsEMBL::Web::Document::HTML;

use constant HELPVIEW_WIN_ATTRIBS => "width=700,height=550,resizable,scrollbars";

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new           {
  return shift->SUPER::new(
    'kw'    => undef,
    'label' => 'Help',
    'URL'   => "/@{[$ENV{'ENSEMBL_SPECIES'}||'perl']}/helpview" ); }
sub URL    :lvalue { $_[0]{'URL'};   }
sub kw     :lvalue { $_[0]{'kw'};    }
sub ref    :lvalue { $_[0]{'ref'};   }
sub action :lvalue { $_[0]{'action'};   }
sub label  :lvalue { $_[0]{'label'};    }

sub render {
  my $self = shift;
  my $link;
  if( $self->URL =~ /^mailto:/ ) {
    $link = sprintf( q(<a href="%s">%s</a>), $self->URL, $self->label ); 
  } else {
    my $extra_HTML = join ";",
      $self->kw     ? "kw=@{[$self->kw]}" : (),
      $self->ref    ? "ref=@{[CGI::escape($self->ref)]}" : (),
      $self->action ? "action=@{[$self->action]}" : ();
    my $URL = $self->URL.($extra_HTML?"?$extra_HTML":"");
    if( $self->action ) { ## ALREADY IN HELP FORM!!
      $link = qq(<a href="$URL">@{[$self->label]}</a>);
    } else {
      $link = sprintf( q(<a href="javascript:void(window.open('%s','helpview','%s'))" class="red-button">%s</a>),
        $URL, HELPVIEW_WIN_ATTRIBS, $self->label
      );
    }
  }
  $self->print( qq(
<div id="help"><strong>$link</strong></div>));
}

1;

