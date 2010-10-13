# $Id$

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;

our $IMAGE_TYPE = '.gif';
use EnsEMBL::Web::Document::HTML::SpeciesLister;

sub render {
  my $class        = shift;
  my $fragment     = shift eq 'fragment';
  my $speciesLister = new EnsEMBL::Web::Document::HTML::SpeciesLister();
  return $speciesLister->render($fragment);
}
1;
