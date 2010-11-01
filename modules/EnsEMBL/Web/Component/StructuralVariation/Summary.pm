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
  my $name                = $object->name;
  my $class               = $object->class;
  my $source              = $object->source;
  my $source_description  = $object->source_description;
 
  $name = "$class ($name)";
  my $source_link = $hub->get_ExtURL_link($source, 'DGVA', $source);
  if($source_description =~/PMID/){ 
    my @temp = split('\s', $source_description);
    foreach (@temp ){
      if ($_ =~/PMID/){
        my $pubmed_id = $_; 
        my $id = $pubmed_id;  
        $id =~s/PMID\://; 
        my $pubmed_url = $hub->get_ExtURL_link($pubmed_id, 'PUBMED', $id); 
        $source_description =~s/$_/$pubmed_url/;
      }
    }
  }   

  $source = "$source_link - $source_description";
 
  my $location = $object->neat_sr_name($object->Obj->slice->seq_region_name .":" . $object->Obj->start ."-" . $object->Obj->end);
  my $strand = $object->Obj->strand > 0 ? "forward" : "reverse";
  my $location_url = $self->hub->url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $object->Obj->slice->seq_region_name.':'.$object->Obj->start.'-'.$object->Obj->end
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
      <dt>Location<dt>
      <dd>$location_link</dd> 
    </dl>
  };
 

  return $html;
}

1;
