package EnsEMBL::Web::Document::HTML::GlobalContext;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub add_link {
  my $self = shift;
  push @{$self->{'_links'}}, {@_};
}

sub links {
  my $self = shift;
  return $self->{'_links'}||[];
}

sub render {
  my $self = shift;
  $self->print( '
    <dl id="global">' );
  foreach my $link ( @{$self->links} ) {
    $self->printf( '
      <dd%s><a href="%s">%s</a></dd>',
      $link->{'current'} ? ' class="current"' : '',
      CGI::escapeHTML( $link->{'URL'} ),
      CGI::escapeHTML( $link->{'txt'} )
    );
  }
  $self->print('
      <dt class="sep"><a href="#">Configure page</a></dt>
      <dt><a href="#">User data</a></dt>
    </dl>' );
}

return 1;
