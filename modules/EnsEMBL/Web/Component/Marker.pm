package EnsEMBL::Web::Component::Marker;

# outputs chunks of XHTML for marker-based displays

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

our $MAX_MAP_WEIGHT = 15;

sub spreadsheet_markerMapLocations {
  my($panel, $data) = @_;

  $panel->add_columns(
    { 'key' => 'map', 'align'=>'center', 'title' => 'Map Name'   },
    { 'key' => 'syn', 'align'=>'center', 'title' => 'Synonym'    },
    { 'key' => 'chr', 'align'=>'center', 'title' => 'Chromosome' },
    { 'key' => 'pos', 'align'=>'center', 'title' => 'Position'   },
    { 'key' => 'lod', 'align'=>'center', 'title' => 'LOD Score'  },
  );
  foreach my $ml (@{$data->markerMapLocations($data)}) {
    $panel->add_row( {
      'map' => $ml->map_name,
      'syn' => $ml->name || '-',
      'chr' => $ml->chromosome_name || '&nbsp;' ,
      'pos' => $ml->position || '-',
      'lod' => $ml->lod_score || '-',
      '_raw' => $ml
    });
  }
}

sub name {
  my($panel, $data) = @_;
  my $important_synonyms = $data->markerSynonyms->{ 'main' };
  return 1 unless @$important_synonyms;

  my $label = 'Marker Source';
  my $html = "<dl>";
  foreach my $synonym (@$important_synonyms){
    my $db = $synonym->source; 
    my $id = $synonym->name;
    my $url = $data->get_ExtURL($db, $id) ;
       $id  = sprintf( qq(<a href="%s">%s</a>), $url, $id) if $url;
    $html .= "<dt>$id &nbsp;&nbsp;( <b>database:</b> $db )</dt>";
  }
  $html .= "</dl>";
  $panel->add_row( $label, $html );
  return 1;
}

sub location {
  my($panel, $data) = @_;
  my $label = 'Marker Location';    
  my $marker = $data->name;
  my $marker_feats;
  my $count = ($marker_feats = $data->markerFeatures) ? scalar(@$marker_feats) : 0;
  my $sitetype = $data->species_defs->ENSEMBL_SITETYPE;
  my $html = '';
  my %real_chromosomes = map { $_, 1 } @{$data->species_defs->ENSEMBL_CHROMOSOMES};
  if( $count == 0 ) {
    $panel->add_row( 
      $label,
      qq(<p>Marker $marker is not mapped to the assembly in the current $sitetype database</p>)
    );
    return 1;
  }
  if( $count > 1 ) {
    $html .= sprintf '<dl>
  <dt>%s is currently mapped to %d different %s locations%s</dt>',
    $marker, $count, $sitetype, ( $count > $MAX_MAP_WEIGHT ? '.' : ':' );
  }
  unless( $count > $MAX_MAP_WEIGHT ) {
    foreach my $feature (@$marker_feats){
      my $name  = $feature->seq_region_name;
      my $start = $feature->start;
      my $end   = $feature->end;
      $html .= sprintf qq(\n  %sBasepairs <a href="%s">%d - %d</a> on %s %s),
        ( $count > 1 ? '<dd>' : '<p>' ),
        $data->location_URL( $feature, undef, 10000), $start, $end,
        $feature->coord_system_name, 
		$name,
		( $count > 1 ? '</dd>' : '</p>' );
    }
  }
  if( $count > 1 ) {
    $html .= '</dl>';
  }
  $panel->add_row($label, $html);
  return 1;
}

sub synonyms {
  my($panel, $data) = @_;
  my $label = 'Marker Synonyms';    
  my $other_synonyms = $data->markerSynonyms->{'other'};
  return 1 unless $other_synonyms;
  my $html = qq(<table>);
  my %source;
  my %counter;
  my $max_count = 0 ;
  foreach my $synonym (@$other_synonyms){
    my $src_name = ucfirst($synonym->source) || 'Other';
    $counter{$src_name}++;
    push @{$source{$src_name}}, $synonym->name ;    
    $max_count = $counter{$src_name} if ($max_count < $counter{$src_name} );    
  } 
  my $cols = ($max_count / 5) ;
  $cols++ if $max_count % 5;
  foreach my $key (sort keys %source){
    $html .= qq(<tr><td><strong>$key : </strong></td>);
    for (1..$cols) {
      my @list = splice (@{$source{$key}} ,0 ,5);
      $html .= qq(<td>);
      foreach my $id (@list) {
        my $url = $data->get_ExtURL(uc($key), $id) ;
        $id  = sprintf( qq(<a href="%s">%s</a>), $url, $id) if $url;
        $html .= $id.qq(&nbsp;<br />);
      }
      $html .= qq(</td>);
    }
    $html .= qq(</tr>);
  }    
  $html .= "</table>";
  $panel->add_row($label, $html);
  return 1;
}


sub primers {
  my($panel, $data) = @_;
  my $label = 'Marker Primers';    
  my $marker = $data->name;
  my $marker_obj = $data->marker;
  my $l = $marker_obj->left_primer;
  my $r = $marker_obj->right_primer;
  my $min_psize = $marker_obj->min_primer_dist;
  my $max_psize = $marker_obj->max_primer_dist;
  my $product_size;
  my $html;
  if(!$min_psize) {
    $product_size = "&nbsp";
  } elsif($min_psize == $max_psize) {
    $product_size = "$min_psize";
  } else {
    $product_size = "$min_psize - $max_psize";
  }
  if(! $l){
    $html = "<p><strong>Marker $marker primers are not in the database</strong></p>";
  } else {
    $l =~ s/([\.\w]{30})/$1<br \/>/g;
    $r =~ s/([\.\w]{30})/$1<br \/>/g;
    $html = qq(
<table>
  <tr>
    <th style="width:20%">Expected Product Size</th>
    <th>Left Primer</th>
    <th>Right Primer</th>
  </tr>
  <tr>
    <td class="center">$product_size</td>
    <td>$l</td>
    <td>$r</td>
  </tr>
</table>);
  }
  $panel->add_row( $label, $html );
  return 1;
}

sub map_locations {
  my($panel, $data) = shift;
  my $marker_map_locations = $data->markerMapLocations;
  return 1  unless @$marker_map_locations;
  $panel->add_columns(
    { 'key' => 'map', 'title' => 'Map Name',   'width' => '25%', 'align' => 'center' },
    { 'key' => 'syn', 'title' => 'Synonym',    'width' => '25%', 'align' => 'center' }, 
    { 'key' => 'Chr', 'title' => 'Chromosome', 'width' => '15%', 'align' => 'center' },
    { 'key' => 'pos', 'title' => 'Position',   'width' => '25%', 'align' => 'center' },
    { 'key' => 'lod', 'title' => 'LOD Score',  'width' => '35%', 'align' => 'center' }
  );
  $panel->add_row( @$marker_map_locations );
  return 1;
}

1;    
