package EnsEMBL::Web::ZMenu::Supporting_alignment;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $id           = $object->param('id');
  my $db           = $object->param('fdb') || $object->param('db') || 'core'; 
  my $object_type  = $object->param('ftype');
  my $db_adaptor   = $object->database(lc($db));
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name;
  my $features     = $feat_adap->fetch_all_by_hit_name($id) || [];

  $self->caption($id);

  if ($features->[0]->analysis->logic_name =~ /intron/) {

    if (scalar(@$features) > 1) { warn "multiple intron objects, not good";}

    my $r = $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end;
    $self->add_entry({
      type  => 'Location',
      label => $r,
    });

    my $score = $features->[0]->score;
    $self->add_entry({
      type  => 'Read coverage',
      label => $score,
    });
  }

  else {
#    foreach my $feat (@$features) {
#      my $evalue = $feat->{'p_value'};
#      $self->add_entry({
#	type  => 'RPKM',
#	label => $evalue,
#      });
#    }
#  }

  $self->add_entry({ 
    label => 'View all hits',
    link  => $object->_url({
      type   => 'Location',
      action => 'Genome',
      ftype  => $object_type,
      id     => $id,
      db     => $db
    })
  });

  $self->add_entry({
    label_html => $features->[0]->analysis->description
  });
}

1;
