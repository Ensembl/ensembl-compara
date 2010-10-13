# $Id$

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
use EnsEMBL::Web::Document::HTML::SpeciesLister;

sub render {
  my $class        = shift;
  my $fragment     = shift;
  my $speciesLister = new EnsEMBL::Web::Document::HTML::SpeciesLister();
  return $speciesLister->render($fragment);
}
1;
