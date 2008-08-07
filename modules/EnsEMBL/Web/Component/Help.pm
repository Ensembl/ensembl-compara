package EnsEMBL::Web::Component::Help;

use base qw( EnsEMBL::Web::Component);
use strict;
use warnings;

use constant 'HELPVIEW_IMAGE_DIR'   => "/img/help";

sub _link_mapping {
  my ($object, $content) = @_;

  ## internal (Ensembl) links
  $content =~ s/HELP_(.*?)_HELP/$object->_help_URL({'kw'=>"$1"})/mseg;

  ## images
  my $replace = HELPVIEW_IMAGE_DIR;
  $content =~ s/IMG_(.*?)_IMG/$replace\/$1/mg;

  return $content;
}

sub _kw_hilite {
  ### Highlights the search keyword(s) in the text
  my ($object, $content) = @_;
  my $kw = $object->param('search') || $object->param('kw');

  $content =~ s/($kw)(?!(\w|\s|[-\.\/;:#\?"])*>)/<span class="hilite">$1<\/span>/img;
  return $content;
}

1;
