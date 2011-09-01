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
  my $hit_url    = $hub->get_ExtURL_link($link_name, $hit_db, $link_name);
  my $havana_derived = $hub->param('havana');
  my $explanation = ($havana_derived || $hub->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Supporting evidence from Havana' : 'Supporting evidence from Ensembl';

  $self->caption("$hit_name ($hit_db)");
  $self->add_entry({
    label_html => $explanation
  });
  $self->add_entry({
    type  => 'View record',
    label => $hit_name,
    link  => $hit_url,
    extra => { abs_url => 1 }
  });
}

1;
