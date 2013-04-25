# $Id$

package EnsEMBL::Web::ZMenu::Gene;

use strict;

use EnsEMBL::Web::ZMenu::Transcript;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  if ($self->click_location) {
    my $hub    = $self->hub;
    my $object = $self->object;
    
    push @{$self->{'features'}}, @{EnsEMBL::Web::ZMenu::Transcript->new($hub, $self->new_object('Transcript', $_, $object->__data))->{'features'}} for @{$object->Obj->get_all_Transcripts};
  } else {
    return $self->_content;
  }
}

sub _content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my @xref   = $object->display_xref;
  
  $self->caption($xref[0] ? "$xref[3]: $xref[0]" : 'Novel transcript');
  
  $self->add_entry({
    type  => 'Gene',
    label => $object->stable_id,
    link  => $hub->url({ type => 'Gene', action => 'Summary' })
  });
  
  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $self->thousandify($object->seq_region_start),
      $self->thousandify($object->seq_region_end)
    ),
    link  => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
    })
  });
  
  $self->add_entry({
    type  => 'Gene type',
    label => $object->gene_type
  });
  
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  
  if ($object->analysis) {
    my $label = $object->analysis->display_label . ' Gene';
    $self->add_entry({
      type  => 'Analysis',
      label => $label
    });
    
    $self->add_entry({
      type       => 'Prediction method',
      label_html => $object->analysis->description
    });
  }
}

1;
