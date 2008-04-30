package EnsEMBL::Web::Document::HTML::GlobalContext;

### Generates the global context navigation menu, used in dynamic pages

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub add_link {
### a
  my $self = shift;
  push @{$self->{'_links'}}, {@_};
}

sub links {
### a
  my $self = shift;
  return $self->{'_links'}||[];
}

sub render {
  my $self = shift;
  $self->print( '<div id="nav">
    <dl id="global">' );
  foreach my $link ( @{$self->links} ) {
    $self->printf( '
      <dd%s><a href="%s">%s</a></dd>',
      $link->{'current'} ? ' class="current"' : '',
      CGI::escapeHTML( $link->{'URL'} ),
      CGI::escapeHTML( $link->{'txt'} )
    );
  }
=pod
  $self->print('
      <dt class="sep"><a href="#">Configure page</a></dt>
      <dt><a href="#">User data</a></dt>
    </dl>' );
=cut
}

return 1;
