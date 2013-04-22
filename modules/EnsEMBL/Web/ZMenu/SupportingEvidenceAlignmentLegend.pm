# $Id$

package EnsEMBL::Web::ZMenu::SupportingEvidenceAlignmentLegend;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $hit_name   = $hub->param('id');
  my $hit_db     = $self->object->get_sf_hit_db_name($hit_name);
  my $link_name  = $hit_db eq 'RFAM' ? [ split '-', $hit_name ]->[0] : $hit_name;
  my $hit_length = $hub->param('hit_length');

  $self->caption("$hit_name ($hit_db)");
  
  $self->add_entry({
    label_html => $hub->param('havana') || $hub->species_defs->ENSEMBL_SITETYPE eq 'Vega' ? 'Supporting evidence from Havana' : 'Supporting evidence from Ensembl'
  });
  
  $self->add_entry({
    type    => 'View record',
    label   => $hit_name,
    link    => $hub->get_ExtURL_link($link_name, $hit_db, $link_name),
    abs_url => 1
  });
}

1;
