package EnsEMBL::Web::ZMenu::StructuralVariationGroup;

use strict;

use base qw(EnsEMBL::Web::ZMenu);


sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $r        = $hub->param('r');
  my $id       = $hub->param('id');
  my $set_name = $hub->param('set_name');
	my $somatic  = $hub->param('somatic');
	my $group    = $hub->param('group');
	
  my ($chr, $loc)    = split ':', $r;
  my ($start, $end) = split '-', $loc;
  my $link = '<a href="%s">%s</a>';
  
  my $db_adaptor = $hub->database('core');
  my $slice_adaptor = $db_adaptor->get_SliceAdaptor;
  my $slice = $slice_adaptor->fetch_by_region('chromosome',$chr,$start,$end);
  
  my $svars;
  if (defined($set_name)) {
	  my $sv_set = $hub->get_adaptor('get_VariationSetAdaptor', 'variation')->fetch_by_name($set_name);
    $svars = $slice->get_all_StructuralVariationFeatures__by_VariationSet($sv_set) || [];
  } else {
	  my $func = defined($somatic) ? 'get_all_somatic_StructuralVariationFeatures' : 'get_all_StructuralVariationFeatures';
    $svars   = $slice->$func() || []; 
	}
	
	if (defined($group)) {
		my @sv_list;
		foreach my $sv (@$svars) {
			my $seq_start = $sv->seq_region_start;
      my $seq_end   = $sv->seq_region_end;
      if ($group == 1) {
        push (@sv_list, $sv) if ($seq_start >= $slice->start || $seq_end <= $slice->end);
      } elsif ($group == 2) {
        push (@sv_list, $sv) if ($seq_start < $slice->start && $seq_end > $slice->end);
      }
		}
		$svars = \@sv_list;
	}
  
  my $location_link = $hub->url({
       type   => 'Location',
       action => 'View',
       r      => $chr . ':' . $start . '-' . $end,
       contigviewbottom => "$id=normal",
     });
  
  my $count = scalar(@$svars);
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
  
  if ($group == 1) {
		$self->add_entry({
      label => "$count structural variants are in this block",
    });
		$self->add_entry({
      label => "Change the display option to 'expanded' in order to show all the structural variants from this track",
    });
    $self->add_entry({
      label_html => 'Zoom in',
      link       => $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $chr . ':' . $start . '-' . $end,
        contigviewbottom => "variation_feature_structural_larger=compact,variation_feature_structural_smaller=gene_nolabel",
      })
    });
	} else {
	  my $view = '';
		$view .= ',somatic_sv_feature=gene_nolabel' if (defined($somatic));
	
   	$self->add_entry({
     	label => "$count structural variants completely overlap the image",
   	});
		$self->add_entry({
     	label => "Change the display option to 'expanded' in order to show all the structural variants from this track",
   	});
   	$self->add_entry({
      label_html => 'Zoom out x2',
      link       => $hub->url({
        type   => 'Location',
        action => 'View',
        r      => $chr . ':' . $zoom_start . '-' . $zoom_end,
        contigviewbottom => "variation_feature_structural_larger=compact,variation_feature_structural_smaller=gene_nolabel$view",
      })
   	});
	}
}

1;

