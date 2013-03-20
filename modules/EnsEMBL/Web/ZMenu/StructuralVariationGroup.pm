package EnsEMBL::Web::ZMenu::StructuralVariationGroup;

use strict;

use base qw(EnsEMBL::Web::ZMenu);


sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $r  = $hub->param('r');
  my $id = $hub->param('id');
  my $set_name = $hub->param('set_name');
  my ($chr, $loc)    = split ':', $r;
  my ($start, $end) = split '-', $loc;
  my ($min_length,$max_length) = split('-', $hub->param('length'));
  my $link = '<a href="%s">%s</a>';
  
  my $db_adaptor = $hub->database('core');
  my $slice_adaptor = $db_adaptor->get_SliceAdaptor;
  my $slice = $slice_adaptor->fetch_by_region('chromosome',$chr,$start,$end);
  
  
  
  my $svars;
  if (defined($min_length)) {
    $svars = $slice->get_all_StructuralVariationFeatures_by_size_range($min_length,$max_length);
  } else {
    $svars = $slice->get_all_StructuralVariationFeatures() || []; 
  }
  
  my $location_link = $hub->url({
       type   => 'Location',
       action => 'View',
       r      => $chr . ':' . $start . '-' . $end,
       contigviewbottom => "$id=normal",
     });
  
  my $count = 0;
  foreach my $sv (@$svars) {
    $count ++ if ($sv->seq_region_start < $slice->start && $sv->seq_region_end > $slice->end);
  }

  my $s = ($count > 1) ? 's' : '';
    
    
  $self->caption("Structural variations ($count variant$s)");
  
  $self->add_entry({
    type  => 'Location',
    label => ($start==$end) ? "$chr:$start" : $r,
    link  => $location_link,
  });
  

  my $length = $end-$start+1;
  my $zoom_start = ($start-$length > 0) ? $start-$length : 1 ;
  my $zoom_end   = $end + $length;


  $self->add_entry({
    label => "$count structural variants overlap completely the image",
  });
  $self->add_entry({
      label_html => 'Expanded structural variant view',
      link       => $hub->url({
         type   => 'Location',
         action => 'StructuralVariant',
         r      => $chr . ':' . $start . '-' . $end,           
       })
  });


}

1;

