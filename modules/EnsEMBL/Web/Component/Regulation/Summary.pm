package EnsEMBL::Web::Component::Regulation::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';


  my $url = $self->hub->url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $object->seq_region_name.':'.$object->bound_start.'-'.$object->bound_end
  });

  my $location_html = sprintf( '<a href="%s">%s: %s-%s</a>',
    $url,
    $object->neat_sr_name( $object->seq_region_type, $object->seq_region_name ),
    $object->thousandify( $object->seq_region_start ),
    $object->thousandify( $object->seq_region_end ),
  );  
  $html .= qq(
    <dl class="summary">
    <dt>Location</dt>
    <dd>$location_html</dd>
  );

  my $table = '<table  margin = "3em 0px">';
  $table .= '<thead><tr><th>Cell line</th><th>Feature type</th><th>Bound co-ordinates</th></tr></thead><tbody>';

  my $all_objs = $object->fetch_all_objs;
  foreach my $reg_object (sort { $a->feature_set->cell_type->name cmp $b->feature_set->cell_type->name } @$all_objs ){
    next if $reg_object->feature_set->cell_type->name =~/MultiCell/;
    $table .= '<tr>';
    $table .='<td>'. $reg_object->feature_set->cell_type->name .'</td>';
    $table .='<td>'. $reg_object->feature_type->name . '</td>';
    my $bound_ends;
    $bound_ends .= $reg_object->bound_start ."-". $reg_object->bound_end;
    $table .='<td>'. $bound_ends .'</td>';
    $table .= '</tr>';
  }
  $table .='</tbody></table>';


  $html .= qq(
    <dt></dt>
    <dd>$table</dd>
  </dl>
  );


  return $html;
}

1;
