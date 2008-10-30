package EnsEMBL::Web::Component::Location::MarkerDetails;

# outputs chunks of XHTML for marker-based displays

use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Document::HTML::TwoCol;
use Bio::EnsEMBL::Registry;
use strict;
use warnings;
no warnings "uninitialized";

my $MAX_MAP_WEIGHT = 15;

sub _init {
  my $self = shift;
  $self->ajaxable( 0 );
}

sub content {
    my $self = shift;
    my $object = $self->object;
    my $species = $object->species;
    my $html;
    my $to_list = 1;
    my $mfs = [];
    my $markers = [];
    my $found_mf = [];
    if (my $m = $object->param('m')) {
	my $adap = Bio::EnsEMBL::Registry->get_adaptor($species,'core','Marker');
        $markers = $adap->fetch_all_by_synonym($m);
	$html = $self->render_marker_details($markers);
    }
    else {
	my $threshold   = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
	if( $object->length > $threshold ) {
	    return $self->_warning( 'Region too large',
				    '<p>The region selected is too large to display in this view</p>' );
	}
	foreach my $mf (@{$object->Obj->{'slice'}->get_all_MarkerFeatures()}) {
	    push @{$found_mf}, $mf;
	}
	$html = $self->render_marker_features($found_mf);
    }
    return $html;
}

# depending on number print a list of marker_features, or show details for markers
sub render_marker_features {
    my $self = shift;
    my ($found_mf)  = @_;
    my $object   = $self->object;
    my $species  = $object->species;
    my $html;
    if ( scalar(@$found_mf) > 2 ) {
	my $c = 0;
	my $link;
	foreach my $mf (@$found_mf) {
	    $c++;
	    my $name = $mf->marker->display_MarkerSynonym->name;
	    my $loc  = $self->get_mf_location($mf);
	    $link .= sprintf(qq(<p><a href = "/%s/Location/Marker?m=%s;r=%s">%s</a> (%s)</p>%s),$species,$name,$loc,$name,$loc);
	}
	$html= qq(<h3>$c mapped markers found:</h3>);
	$html .= $link;
	return $html;
    }
    else {
	my $markers = [];
	foreach my $mf (@$found_mf) {
	    push @{$markers}, $mf->marker;
	}
	return $self->render_marker_details($markers);
    }
}

sub render_marker_details {
#    use Data::Dumper;
    my $self = shift;
    my ($markers)  = @_;
    my $object   = $self->object;
    my $species  = $object->species;
    my $html;
    foreach my $m (@$markers) {
	my $table  = new EnsEMBL::Web::Document::HTML::TwoCol;
	my $m_name = $m->display_MarkerSynonym->name;
	$html .= qq(<h3>Marker $m_name</h3>);

	#synonyms
	if (my @important_syns = @{$self->markerSynonyms($m,1)}) {
	    my $syn_text;
	    foreach my $syn (@important_syns){
		my $db = $syn->source;
		my $id = $syn->name;
		my $url = $object->get_ExtURL($db, $id) ;
		$id  = sprintf( qq(<a href="%s">%s</a>), $url, $id) if $url;
		$syn_text .= qq(<table><tr><td>$id ($db)</td></tr></table>);
	    }
	    $table->add_row('Source',
			    $syn_text,
			    1);
	}
	
	#location of marker features
	my $loc_text = $self->render_location($m);
	$table->add_row('Location',
			$loc_text,
			1);
	
	#other synonyms (rows of $max_cols entries)
	if (my @other_syns = @{$self->markerSynonyms($m,0)}) {
	    my $max_cols = 8;
	    my $syn_dbs;		
	    foreach my $syn (@other_syns) {
		my $db_name = $syn->source;
		push @{$syn_dbs->{$db_name}},$syn->name;
	    }
	    my $other_syn_text = qq(<table><tr>);
	    foreach my $db (keys %{$syn_dbs}) {
		my $c = 0;
		$other_syn_text .= qq(<td><strong>$db:</strong></td>);
		foreach my $id (@{$syn_dbs->{$db}}) {
		    my $url = $object->get_ExtURL_link( $id, uc($db), $id);
		    if ($c < $max_cols) {
			$other_syn_text .= qq(<td>$url</td>);
			$c++;
		    }
		    else {
			$other_syn_text .= qq(</tr>
                                                   <tr><td></td><td>$url</td>);
			$c = 1;
		    }
		}			
		$other_syn_text .= qq(</tr>);
	    }
	    $other_syn_text .= qq(</table>);
	    
	    $table->add_row('Synonyms',
			    $other_syn_text,
			    1);
	    }
	
	#primer details
	my $l = $m->left_primer;
	my $r = $m->right_primer;
	my $min_psize = $m->min_primer_dist;
	my $max_psize = $m->max_primer_dist;
	my $product_size;
	if (!$min_psize) {
	    $product_size = "&nbsp";
	}
	elsif ($min_psize == $max_psize) {
	    $product_size = "$min_psize";
	}
	else {
	    $product_size = "$min_psize - $max_psize";
	}
	my $primer_txt;
	if ($r) {
	    $l =~ s/([\.\w]{30})/$1<br \/>/g;
	    $r =~ s/([\.\w]{30})/$1<br \/>/g;
	    $primer_txt .= qq(<table>
                                    <tr><td><strong>Expected Product Size:</strong></td><td>$product_size</td></tr>
                                    <tr><td><strong>Left Primer:</strong></td><td>$l</td></tr>
                                    <tr><td><strong>Right Primer:</strong></td><td>$r</td></tr>
                                  </table>);
	}
	else {
	    $primer_txt = qq(Marker $m_name primers are not in the database);
	}
	$table->add_row('Primers',
			$primer_txt,
			1);
	
	$html .= $table->render;
	
	if (my @mml = @{$m->get_all_MapLocations()}) {
	    my $map_table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
	    $map_table->add_columns({ 'key' => 'map', 'align'=>'left', 'title' => 'Map Name'});
	    $map_table->add_columns({ 'key' => 'syn', 'align'=>'left', 'title' => 'Synonym'    });
	    $map_table->add_columns({ 'key' => 'chr', 'align'=>'left', 'title' => 'Chromosome' });
	    $map_table->add_columns({ 'key' => 'pos', 'align'=>'left', 'title' => 'Position'   });
	    $map_table->add_columns({ 'key' => 'lod', 'align'=>'left', 'title' => 'LOD Score'  });
	    foreach my $ml (@mml) {
		my $row = {'map' => $ml->map_name,
			   'syn' => $ml->name || '-',
			   'chr' => $ml->chromosome_name || '&nbsp;' ,
			   'pos' => $ml->position || '-',
			   'lod' => $ml->lod_score || '-',
			   '_raw' => $ml,};
		$map_table->add_row($row);
		}
	    $html .= $map_table->render;
	}		
    }
    return $html;
}

sub markerSynonyms {
    my $self = shift;
    my $m = shift;
    my $important = shift;
    my $syns = [];
    my %IS_IMPORTANT = map { $_, 1 } qw( rgd oxford unists mgi:markersymbol );
    foreach my $ms ( @{ $m->get_all_MarkerSynonyms } ) {
	if ($important) {
	    push @{$syns}, $ms if $IS_IMPORTANT{ lc($ms->source) };
	}
	else {
	    push @{$syns}, $ms unless $IS_IMPORTANT{ lc($ms->source) };
	}
    }
    return $syns;
}

sub render_location {
    my $self = shift;
    my $m = shift;
    my $m_name   = $m->display_MarkerSynonym->name;
    my $object   = $self->object;
    my $species  = $object->species;
    my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
    my $mfs;
    my $c = ($mfs = $m->get_all_MarkerFeatures) ? scalar(@$mfs) : 0;
    my $loc_text = qq(<table>);
    if ($c) {
	if ($c > 1) {
	    $loc_text .= sprintf (qq(<tr><td>%s is currently mapped to %d different %s locations%s</td></tr>),
				  $m_name,
				  $c,
				  $sitetype,
				  ( $c > $MAX_MAP_WEIGHT ? '.' : ':' ) );
	}
	foreach my $mf (@$mfs){
	    my $sr_name = $mf->seq_region_name;
	    my $start   = $mf->start;
	    my $end     = $mf->end;
	    $loc_text .= sprintf (qq(<tr><td>%s%s <a href="%s">%s:%d-%d</a></td></tr>),
				  ($c > 1) ? '&nbsp;' : '',
				  $mf->coord_system_name,
				  "/$species/Location/View?r=$sr_name:$start-$end;h=$m_name",
				  $sr_name,
				  $start,
				  $end);
	}
    }
    else {
	$loc_text .= qq(<tr><td>Marker $m_name is not mapped to the assembly in the current $sitetype database</td></tr>);
    }
    $loc_text .= qq(</table>);
    return $loc_text;
}


sub get_mf_location {
    my $self = shift;
    my $mf = shift;
    my $sr_name = $mf->seq_region_name;
    my $start   = $mf->seq_region_start;
    my $end     = $mf->seq_region_end;
    return "$sr_name:$start-$end";
}

1;
