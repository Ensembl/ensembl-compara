package EnsEMBL::Web::Component::StructuralVariation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my $object              = $self->object;
	my $sv_obj              = $object->Obj;
  my $name                = $object->name;
  my $class               = $object->class;
  my $source              = $object->source;
  my $source_description  = $object->source_description;
  my $study_name          = $object->study_name;
  my $study_description   = $object->study_description;
  my $study_url           = $object->study_url;
  my $supporting_sv				= $object->supporting_sv;
  $name = "$class ($name)";
  my $source_link = $hub->get_ExtURL_link($source, 'DGVA', $source);
 
  $source_description = add_pubmed_link($source_description, $hub);
  
	$source = "$source_link - $source_description";
 	
	# Study line display
	my $study_line = '';
  if ($study_name ne '') {
		$study_description = add_pubmed_link($study_description, $hub);
    $study_line = sprintf ('<a href="%s">%s</a>',$study_url,$study_name);
  	$study_line = "<dt>Study</dt><dd>$study_line - $study_description</dd>";
  }
	
	# Supporting evidence
	my $ssv_line = '';
	if (scalar @{$supporting_sv} > 0) {
		$ssv_line = "<dt>Supporting evidence</dt>\n<dd>";
		my $ssv_sep = '';
		my $ssv_count = 1;
		my $ssv_limit = 15;
		foreach my $ssv (@{$supporting_sv}) {
			$ssv_line .= "$ssv_sep".$ssv->name;
			if ($ssv_sep eq '') { $ssv_sep = ', '; }
			if ($ssv_count==$ssv_limit) { 
				$ssv_line .= $ssv_sep.'<br />';
				$ssv_count = 0;
				$ssv_sep = '';
			}
			$ssv_count++;
		}
		$ssv_line .= "</dd>";
	} 
 
  my $location = $object->neat_sr_name($sv_obj->slice->seq_region_name .":" . $sv_obj->start ."-" . $sv_obj->end);
  my $strand = $sv_obj->strand > 0 ? "forward" : "reverse";
  my $location_url = $self->hub->url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $sv_obj->slice->seq_region_name.':'.$sv_obj->start.'-'.$sv_obj->end
  });
  $location_url .= "contigviewbottom=variation_feature_structural=normal";

  my $location_html = sprintf( '<a href="%s">%s</a>.',
    $location_url,
    'View in location tab'
  );
	
  my $location_link = "This feature maps to $location ($strand strand) | $location_html";
 
  my $html = qq{
    <dl class="summary">
      <dt>Variation class</dt>
      <dd>$name</dd>
      <dt>Source</dt>
      <dd>$source</dd>
	    $study_line
      <dt>Location</dt>
      <dd>$location_link</dd>
			$ssv_line 
    </dl>
  };
	
  return $html;
}


# Method to add a pubmed link to the expression "PMID:xxxxxxx"
# in the source or study description, if it is present.
sub add_pubmed_link{
	my $s_description = shift;
	my $hub = shift;
	if($s_description =~/PMID/){ 
		my @temp = split('\s', $s_description);
    foreach (@temp ){
			if ($_ =~/PMID/){
      	my $pubmed_id = $_; 
        my $id = $pubmed_id;  
        $id =~s/PMID\://; 
        my $pubmed_url = $hub->get_ExtURL_link($pubmed_id, 'PUBMED', $id); 
        $s_description =~s/$_/$pubmed_url/;
			}
		}
 	}
	return $s_description;
}

1;
