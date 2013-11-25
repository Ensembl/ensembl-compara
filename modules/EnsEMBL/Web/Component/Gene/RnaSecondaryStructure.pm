# $Id$

package EnsEMBL::Web::Component::Gene::RnaSecondaryStructure;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $html;

  $html .= '<h4>Key</h4><img src="/img/r2r_legend.png" />';

  my ($display_name) = $object->display_xref;

  my $svg_path = $self->draw_structure($display_name);
  if ($svg_path) {
    $html .= qq(<object data="$svg_path" type="image/svg+xml"></object>);
  }

  return $html;
}

1;
