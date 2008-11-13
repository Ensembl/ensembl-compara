package EnsEMBL::Web::Component::Help;

use base qw( EnsEMBL::Web::Component);
use strict;
use warnings;

use constant 'HELPVIEW_IMAGE_DIR'   => "/img/help";

sub kw_hilite {
  ### Highlights the search keyword(s) in the text, omitting HTML tag contents
  my ($self, $content) = @_;
  my $kw = $self->object->param('string');
  return $content unless $kw;

  $content =~ s/($kw)(?!(\w|\s|[-\.\/;:#\?"])*>)/<span class="hilite">$1<\/span>/img;
  return $content;
}

1;
