#$Id$
package EnsEMBL::Web::Component::Marker::Details;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Document::HTML::TwoCol;
use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->ajaxable(0);
}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $markers = $object->Obj;
  my $hub     = $self->hub;
  my $species = $hub->species;
  my $html;
  
  return '<h3>No markers found</h3>' unless scalar @$markers;
  
  foreach my $m (@$markers) {
    my $table  = new EnsEMBL::Web::Document::HTML::TwoCol;
    my $m_name = $m->display_MarkerSynonym ? $m->display_MarkerSynonym->name : '';
    
    $html .= "<h3>Marker $m_name</h3>";
    
    # location of marker features
    $table->add_row('Location', $self->render_location($m), 1);
    
    # synonyms
    if (my @important_syns = @{$self->marker_synonyms($m, 1)}) {
      my $syn_text;
      
      foreach my $syn (@important_syns) {
        my $db  = $syn->source;
        my $id  = $syn->name;
        my $url = $hub->get_ExtURL($db, $id);
        
        $id = qq{<a href="$url">$id</a>} if $url;
        $syn_text .= "<table><tr><td>$id ($db)</td></tr></table>";
      }
      
      $table->add_row('Source', $syn_text, 1);
    }
    
    # other synonyms (rows of $max_cols entries)
    if (my @other_syns = @{$self->marker_synonyms($m, 0)}) {
      my $other_syn_text = '<table><tr>';
      my $max_cols = 8;
      my $syn_dbs;
      
      foreach my $syn (@other_syns) {
        my $db_name = $syn->source;
        push @{$syn_dbs->{$db_name}}, $syn->name;
      }
      
      foreach my $db (keys %$syn_dbs) {
        my $c = 0;
        
        $other_syn_text .= "<td><strong>$db:</strong></td>";
        
        foreach my $id (@{$syn_dbs->{$db}}) {
          my $url = $hub->get_ExtURL_link($id, uc $db, $id);
          
          if ($c < $max_cols) {
            $other_syn_text .= "<td>$url</td>";
            $c++;
          } else {
            $other_syn_text .= "
              </tr>
              <tr>
                <td></td>
                <td>$url</td>";
            
            $c = 1;
          }
        }
        
        $other_syn_text .= '</tr>';
      }
      
      $other_syn_text .= '</table>';
      
      $table->add_row('Synonyms', $other_syn_text, 1);
    }
    
    # primer details
    my $l         = $m->left_primer;
    my $r         = $m->right_primer;
    my $min_psize = $m->min_primer_dist;
    my $max_psize = $m->max_primer_dist;
    my ($product_size, $primer_txt);
    
    if (!$min_psize) {
      $product_size = '&nbsp;';
    } elsif ($min_psize == $max_psize) {
      $product_size = $min_psize;
    } else {
      $product_size = "$min_psize - $max_psize";
    }
    
    if ($r) {
      $l =~ s/([\.\w]{30})/$1<br \/>/g;
      $r =~ s/([\.\w]{30})/$1<br \/>/g;
      
      $primer_txt .= "
      <table>
        <tr><td><strong>Expected Product Size:</strong></td><td>$product_size</td></tr>
        <tr><td><strong>Left Primer:</strong></td><td>$l</td></tr>
        <tr><td><strong>Right Primer:</strong></td><td>$r</td></tr>
      </table>
      ";
    } else {
      $primer_txt = "Marker $m_name primers are not in the database";
    }
    
    $table->add_row('Primers', $primer_txt, 1);
    
    $html .= $table->render;
    
    if (my @mml = @{$m->get_all_MapLocations}) {
      my $map_table = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '1em 0px' });
      
      $map_table->add_columns(
        { key => 'map', align => 'left', title => 'Map Name'   },
        { key => 'syn', align => 'left', title => 'Synonym'    },
        { key => 'chr', align => 'left', title => 'Chromosome' },
        { key => 'pos', align => 'left', title => 'Position'   },
        { key => 'lod', align => 'left', title => 'LOD Score'  }
      );
      
      foreach my $ml (@mml) {
        my $row = {
          'map'  => $ml->map_name,
          'syn'  => $ml->name            || '-',
          'chr'  => $ml->chromosome_name || '&nbsp;' ,
          'pos'  => $ml->position        || '-',
          'lod'  => $ml->lod_score       || '-',
          '_raw' => $ml
        };
        
        $map_table->add_row($row);
      }
      
      $html .= $map_table->render;
    }    
  }
  
  return $html;
}

sub marker_synonyms {
	my ($self, $m, $important) = @_;
  
	my @syns;
	my %is_important = map { $_, 1 } qw(rgd oxford unists mgi:markersymbol);
  
  if ($important) {
    @syns = grep $is_important{lc $_->source}, @{$m->get_all_MarkerSynonyms};
  } else {
    @syns = grep !$is_important{lc $_->source}, @{$m->get_all_MarkerSynonyms};
  }
  
	return \@syns;
}

sub render_location {
  my ($self, $m) = @_;
  
  my $object   = $self->object;
  my $location = $self->model->create_objects('Location', 'lazy');
  my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
  my $name     = $m->display_MarkerSynonym ? $m->display_MarkerSynonym->name : '';
  my $html;
  
  if ($location) {
    my @marker_features = $location->sorted_marker_features($m);
    my $c               = scalar @marker_features;
    my $max_map_weight  = 15;
    my $map_weight      = 2;
    my $priority        = 50;
    
    if ($c) {
      if ($c > 1) {
        $html .= sprintf(
          '<tr><td>%s is currently mapped to %d different %s locations%s%s%s</td></tr>', 
          $name,
          $c,
          $sitetype,
          $c > $map_weight ? ' (note that for clarity markers mapped more than twice are not shown on location based views)' : '',
          $c > $max_map_weight ? '.' : ':'
        );
      }
      
      foreach my $mf (@marker_features) {
        my $sr_name = $mf->seq_region_name;
        my $start   = $mf->start;
        my $end     = $mf->end;
        my $url     = $object->_url({ type => 'Location', action => 'View', r => "$sr_name:$start-$end", m => $name }); 
        my $extra   = $m->priority < $priority ? " [Note that for reasons of clarity this marker is not shown on 'Region in detail']" : '';
        
        $html .= sprintf '<tr><td>%s%s <a href="%s">%s:%s-%s</a>%s</td></tr>', $c > 1 ? '&nbsp;' : '', $mf->coord_system_name, $url, $sr_name, $start, $end, $extra;
      }
    }
  }
  
  $html ||= "<tr><td>Marker $name is not mapped to the assembly in the current $sitetype database</td></tr>";
  
  return "<table>$html</table>";
}

1;
