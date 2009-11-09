package EnsEMBL::Web::ZMenu::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift; 
  my $object = $self->object;
  return unless $object->param('vid');

  my $v_id            = $object->param('vid');
  my $vf              = $object->param('vf');
  my $db_adaptor      = $object->database('variation');
  my $var_adaptor     = $db_adaptor->get_StructuralVariation;
  my $variation       = $var_adaptor->fetch_by_dbID($v_id); 
  my $seq_region      = $variation->slice->seq_region_name(); 
  my $seq_region_type = $variation->slice->coord_system->name;
  my $neat_sr_name    = $object->neat_sr_name($seq_region_type, $seq_region);
  my $start           = $object->thousandify(($variation->slice->start  + $variation->start) -1);
  my $end             = $object->thousandify(($variation->slice->start + $variation->end) -1);
  my $position        = $neat_sr_name .':'.$start.'-'.$end;
  my $length          = $end -$start;
  my $action          = 'View';
  my $scale           = $object->species_defs->ENSEMBL_GENOME_SIZE || 1;    
  my $max_length      = $scale *= 1e6;
  my $description     = $variation->source_description; 
  my $pubmed_link     = '';
  my $location_link;

  if ($length >> $max_length) { 
    $action = 'Overview'; 
    $location_link = $object->_url({
      type   => 'Location',
      action => $action,
      r      => $seq_region .':'.$start.'-'.$end,
      cytoview => 'variation_feature_structural=normal'
    });
  } else {
    $location_link = $object->_url({
      type   => 'Location',
      action => $action,
      r      => $seq_region .':'.$start.'-'.$end,
    });
  }
  
  if ($description =~/PMID/) {
    my @description_string = split (':', $description);
    my $pubmed_id = pop @description_string;
    $pubmed_link = $object->get_ExtURL('PUBMED', $pubmed_id);  
  }    

  $self->caption('Structural variation: ' . $variation->variation_name);
  
  $self->add_entry({
    type  => 'Source',
    label => $variation->source,
  });

  $self->add_entry({
    type  => 'Description',
    label => $description,
    link  => $pubmed_link, 
  });

  $self->add_entry({
    type  => 'Class',
    label => $variation->class,
  });

  $self->add_entry({
    type  => 'Location',
    label => $position,
    link  => $location_link,
  });

}

1;
