# $Id$

package EnsEMBL::Web::ZMenu::Transcript;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my @xref   = $object->display_xref;
  
  $self->caption($xref[0] ? "$xref[3]: $xref[0]" : !$object->gene ? $object->Obj->stable_id : 'Novel transcript');
  
  $self->add_entry({
    type  => 'Transcript',
    label => $object->stable_id, 
    link  => $object->_url({ type => 'Transcript', action => 'Summary' })
  });
  
  # Only if there is a gene (not Prediction transcripts)
  if ($object->gene) {
    $self->add_entry({
      type  => 'Gene',
      label => $object->gene->stable_id,
      link  => $object->_url({ type => 'Gene', action => 'Summary' })
    });
    
    $self->add_entry({
      type  => 'Location',
      label => sprintf(
        '%s: %s-%s',
        $object->neat_sr_name($object->seq_region_type,$object->seq_region_name),
        $object->thousandify($object->seq_region_start),
        $object->thousandify($object->seq_region_end)
      ),
      link  => $object->_url({
        type   => 'Location',
        action => 'View',
        r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
      })
    });
    
    $self->add_entry({
      type  => 'Gene type',
      label => $object->gene_stat_and_biotype
    });
  }
  
  $self->add_entry({
    type  => 'Transcript type',
    label => $object->transcript_type
  });
  
  if ($object->get_db eq 'vega' || ($object->Obj->analysis->logic_name =~ /otter/) ) {
    $self->add_entry({
      type  => 'Transcript class',
      label => $object->transcript_class
    });
  }
  
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  
  $self->add_entry({
    type  => 'Base pairs',
    label => $object->thousandify($object->Obj->seq->length)
  });
  
  # Protein coding transcripts only
  if ($object->Obj->translation) {
    $self->add_entry({
      type     => 'Protein product',
      label    => $object->Obj->translation->stable_id || $object->Obj->stable_id,
      link     => $object->_url({ type => 'Transcript', action => 'ProteinSummary' }),
      position => 3
    });
    
    $self->add_entry({
      type  => 'Amino acids',
      label => $object->thousandify($object->Obj->translation->length)
    });
  }
  
  if ($object->analysis) {
    $self->add_entry({
      type  => 'Analysis',
      label => $object->analysis->display_label
    });
    
    $self->add_entry({
      label_html => $object->analysis->description
    });
  }
}

1;
