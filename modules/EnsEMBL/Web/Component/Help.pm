package EnsEMBL::Web::Component::Help;

use base qw( EnsEMBL::Web::Component);
use strict;
use warnings;

use constant 'HELPVIEW_IMAGE_DIR'   => "/img/help";

sub link_mapping {
  my ($object, $content) = @_;

  ## internal (Ensembl) links
  $content =~ s/HELP_(.*?)_HELP/$object->_help_URL({'kw'=>"$1"})/mseg;

  ## images
  my $replace = HELPVIEW_IMAGE_DIR;
  $content =~ s/IMG_(.*?)_IMG/$replace\/$1/mg;

  return $content;
}

sub kw_hilite {
  ### Highlights the search keyword(s) in the text, omitting HTML tag contents
  my ($self, $content) = @_;
  my $kw = $self->object->param('string');
  return $content unless $kw;

  $content =~ s/($kw)(?!(\w|\s|[-\.\/;:#\?"])*>)/<span class="hilite">$1<\/span>/img;
  return $content;
}

1;
