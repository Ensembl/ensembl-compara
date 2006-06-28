package EnsEMBL::Web::Document::HTML::CloseWindow;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new           { return shift->SUPER::new( 'URL' => '', 'kw' => '', 'style' => 'popup' ); }
sub URL   :lvalue { $_[0]{'URL'};   }
sub kw    :lvalue { $_[0]{'kw'};    }
sub style :lvalue { $_[0]{'style'}; }

sub render {
  my $self = shift;
  if( $self->style eq 'help' ) {
    $self->print( qq(
    <div id="closewindow">
    <form action="@{[$self->URL]}" method="get">Search Help:
      <input type="hidden" name="action" value="full_text_search" />
      <input type="text" size="25" name="kw" value="@{[$self->kw]}" />
      <br />Highlight search term(s)
      <input type="checkbox" name="hilite" />
      <input type="submit" class="red-button" value="Go" />
    </form>
  </div>
    ));
  } else {
    my $EXTRA_JAVASCRIPT =  $self->URL ? sprintf( "window.opener.location='%s';", $self->URL ) : '';
    $self->print( qq(
  <div id="closewindow">
    <a class="red-button" href="javascript:${EXTRA_JAVASCRIPT}window.close()">Close Window</a>
  </div>)
    );
  }
}

1;

