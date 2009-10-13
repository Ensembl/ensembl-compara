# $Id$

package EnsEMBL::Web::ZMenu::ProteinSummary;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object      = $self->object;
  my $db          = $object->param('db') || 'core';
  my $pfa         = $object->database(lc($db))->get_ProteinFeatureAdaptor;
  my $pf          = $pfa->fetch_by_dbID($object->param('pf_id'));
  my $hit_db      = $pf->analysis->db;
  my $hit_name    = $pf->display_id;
  my $interpro_ac = $pf->interpro_ac;
  
  $self->caption("$hit_name ($hit_db)");
  
  $self->add_entry({
    type  => 'View record',
    label => $hit_name,
    link  => $object->get_ExtURL($hit_db, $hit_name)
  });
  
  if ($interpro_ac) {
    $self->add_entry({
      type  => 'View InterPro',
      label => 'InterPro',
      link  => $object->get_ExtURL('interpro', $interpro_ac)
    });
  }
  
  $self->add_entry({
    type  => 'Description',
    label => $pf->idesc
  });
  
  $self->add_entry({
    type  => 'Position',
    label => $pf->start . '-' . $pf->end . ' aa'
  });
}

1;
