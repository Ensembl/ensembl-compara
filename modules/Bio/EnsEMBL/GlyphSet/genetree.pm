package Bio::EnsEMBL::GlyphSet::genetree;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub fixed { 
  # ...No idea what this method is for...
  return 1;
}


my $CURRENT_ROW;
my $CURRENT_Y;
my $MIN_ROW_HEIGHT = 20;
sub _init {
  # Populate the canvas with feaures represented as glyphs
  my ($self) = @_;

  my $current_gene          = $self->{highlights}->[0];
  my $current_genome_db     = $self->{highlights}->[1] || ' ';
  my $collapsed_nodes_str   = $self->{highlights}->[2] || '';
  my $coloured_nodes        = $self->{highlights}->[3] || [];
  my $tree          = $self->{'container'};
  my $Config        = $self->{'config'};
  my $bitmap_width = $Config->image_width(); 


  $CURRENT_ROW = 1;
  $CURRENT_Y   = 1;
#  warn ("A-0:".localtime());

  # Handle collapsed/removed nodes
  my %collapsed_nodes = ( map{$_=>1} split( ',', $collapsed_nodes_str ) );  
  $self->{_collapsed_nodes} = \%collapsed_nodes;
  # Keep the collapsed nodes in the URL. This is icky!
  # I have mailed james to see if the arbitrary URL params can be included 
  # by default.
  $self->{'config'}{_core}{'parameters'}{'collapse'} = $collapsed_nodes_str;

  # $coloured_nodes is an array. It is sorted such as the largest clades
  # are used first. In case or a tie (i.e. all the genes are mammals and
  # vertebrates), the smallest clade overwrites the colour.
  foreach my $hash (@$coloured_nodes) {
    my $node_ids = $hash->{'node_ids'};
    my $mode = $hash->{'mode'};
    my $colour = $hash->{'colour'};
    my $clade = $hash->{'clade'};
    foreach my $node_id (@$node_ids) {
      $self->{"_${mode}_coloured_nodes"}->{$node_id} =
          {'clade' => $clade, 'colour' => $colour};
    }
  }

  # Create a sorted list of tree nodes sorted by rank then id
  my @nodes = ( sort { ($a->{_rank} <=> $b->{_rank}) * 10  
                           + ( $a->{_id} <=> $b->{_id}) } 
                @{$self->features($tree, 0, 0 ) || [] } );

#  warn ("B-0:".localtime());

  #----------
  # Calculate pixel widths for the components of the image; 
  # +----------------------------------------------------+
  # | bitmap_width                                       |
  # | tree_width (60%)           | alignment_width (40%) |
  # | nodes_width | labels_width |                       |
  # +----------------------------------------------------+
  # Set 60% to the tree, and 40% to the alignments
  my $tree_bitmap_width  = int( $bitmap_width * 0.6 );
  my $align_bitmap_width = $bitmap_width - $tree_bitmap_width;
  # Calculate space to reserve for the labels
  my( $fontname, $fontsize ) = $self->get_font_details( 'small' );
  my( $longest_label ) = ( sort{ length($b) <=> length($a) } 
                           map{$_->{label}} @nodes );
  my @res = $self->get_text_width( 0, $longest_label, '', 
                                   'font'=>$fontname, 'ptsize' => $fontsize );
  my $font_height = $res[3];
  my $font_width  = $res[2];
  # And assign the rest to the nodes 
  my $labels_bitmap_width = $font_width;
  my $nodes_bitmap_width = $tree_bitmap_width-$labels_bitmap_width;
  #----------
  # Calculate phylogenetic distance to px scaling
  #my $max_distance = $tree->max_distance;
  # warn Data::Dumper::Dumper( @nodes );
  my( $max_x_offset ) = ( sort{ $b <=> $a }
                          map{$_->{_x_offset} + ($_->{_collapsed_distance}||0)}
                          @nodes );
  my $nodes_scale = ($nodes_bitmap_width) / ($max_x_offset||1);
  #----------

  # Colours of connectors; affected by scaling
  my %connector_colours = (
                           0 => 'blue',
                           1 => 'blue',
                           2 => 'green',
                           3 => 'red',
                           );

  
  # Draw each node
  my %Nodes;
  map { $Nodes{$_->{_id}} = $_} @nodes;
  my @alignments;
    my @node_glyphs;
    my @bg_glyphs;
    my @labels;
  foreach my $f (@nodes) {
     # Ensure connector enters at base of node glyph
    my $parent_node = $Nodes{$f->{_parent}} || {x=>0};
    my $min_x = $parent_node->{x} + 4;
    ($f->{x}) = sort{$b<=>$a} int($f->{_x_offset} * $nodes_scale), $min_x;
    
    if ($f->{_cigar_line}){
      push @alignments, [ $f->{y} , $f->{_cigar_line}, $f->{_collapsed} ] ;
    }
    
    # Node glyph, coloured for for duplication/speciation
    my ($node_colour, $label_colour, $collapsed_colour);
    if ($f->{_dup}) {
      $node_colour = ($f->{_dubious_dup} ? 'turquoise' : 'red3');
    }

    if ($f->{label}) {
      if( $f->{_genome_dbs}->{$current_genome_db} ){
        $label_colour     = 'blue';
        $collapsed_colour = 'royalblue';
      }
      if( $f->{_genes}->{$current_gene} ){
        $label_colour     = 'red';
        $collapsed_colour = 'red';
        $node_colour = "royalblue";
      }
    }
    if ($f->{_fg_colour}) {
      # Use this foreground colour for this node if not already set
      $node_colour = $f->{_fg_colour} if (!$node_colour);
      $label_colour = $f->{_fg_colour} if (!$label_colour);
      $collapsed_colour = $f->{_fg_colour} if (!$collapsed_colour);
    }
    $node_colour = "navyblue" if (!$node_colour); # Default colour
    $label_colour = "black" if (!$label_colour); # Default colour
    $collapsed_colour = 'grey' if (!$collapsed_colour); # Default colour

    my $node_href = $self->_url
        ({ 'action'   => 'Compara_Tree_Node',
           'node'     => $f->{'_id'} });

    my $collapsed_xoffset = 0;
    if ($f->{_bg_colour}) {
      my $width  = $bitmap_width;
      my $y = $f->{y_from} + 2;
      my $height = $f->{y_to} - $f->{y_from} - 1;
      my $x = $f->{x};
      my $width = $bitmap_width - $x - 5;
      push @bg_glyphs, Sanger::Graphics::Glyph::Rect->new
          ({
            'x'      => $x,
            'y'      => $y,
            'width'  => $width,
            'height' => $height,
            'colour' => $f->{_bg_colour},
          });
    }
    if( $f->{_collapsed} ){ # Collapsed

      my $height = $f->{_height};
      my $width  = $f->{_collapsed_distance} * $nodes_scale + 10; 
      my $y = $f->{y} + 2;
      my $x = $f->{x} + 2;
      $collapsed_xoffset = $width;
      push @node_glyphs, Sanger::Graphics::Glyph::Poly->new
          ({
            'points' => [ $x, $y,
                          $x + $width, $y - ($height / 2 ),
                          $x + $width, $y + ($height / 2 ) ],
            'colour' => $collapsed_colour,
            'href'   => $node_href,
          });

      my $node_glyph = Sanger::Graphics::Glyph::Rect->new
          ({
            'x'      => $f->{x},
            'y'      => $f->{y},
            'width'  => 5,
            'height' => 5,
            'colour' => $node_colour,
            'href'   => $node_href,
          });
      push @node_glyphs, $node_glyph;

    }
    elsif( $f->{_child_count} ){ # Expanded internal node
      # Add a 'collapse' href
      my $node_glyph = Sanger::Graphics::Glyph::Rect->new
          ({
            'x'         => $f->{x},
            'y'         => $f->{y},
            'width'     => 5,
            'height'    => 5,
            'colour'    => $node_colour,
            'zindex'    => ($f->{_dup} ? 40 : -20),
            'href'      => $node_href
          });
      push @node_glyphs, $node_glyph;

    }
    else{ # Leaf node
      push @node_glyphs, Sanger::Graphics::Glyph::Rect->new
          ({
            'x'         => $f->{x},
            'y'         => $f->{y},
            'width'     => 5,
            'height'    => 5,
            'bordercolour' => $node_colour,
            'zindex'    => -20,
            'href'      => $node_href,
          });
    }
    
    # Leaf label or collapsed node label, coloured for focus gene/species
    if ($f->{label}) {
      # Draw the label
      my $txt = $self->Text
          ({
            'text'       => $f->{label},
            'height'     => $font_height,
            'width'      => $labels_bitmap_width,
            'font'       => $fontname,
            'ptsize'     => $fontsize,
            'halign'     => 'left',
            'colour'     => $label_colour,
            'y' => $f->{y} - int($font_height/2),
            'x' => $f->{x} + 10 + $collapsed_xoffset,
            'zindex' => 40,
	  });

      if( my $stable_id = $f->{_gene} ){ # Add a gene href
        my $species = $f->{'_species'};
        $species =~ s/\s/_/g;
        my $href = $self->_url( {'species' => $species,
                                 'type'    => 'Gene',
                                 'action'  => 'Compara_Tree',
                                 '__clear' => $stable_id != $self->{'config'}{_core}{'parameters'}{'g'}, 
                                 'r'       => undef,
                                 'g'       => $stable_id } );
        $txt->{'href'} = $href;
      }
      
      push(@labels, $txt);


    }
  }
    
  $self->push( @bg_glyphs );

  my $max_x = (sort {$a->{x} <=> $b->{x}} @nodes)[-1]->{x};
  my $min_y = (sort {$a->{y} <=> $b->{y}} @nodes)[0]->{y};

#  warn ("MAX X: $max_x" );
#  warn ("C-0:".localtime());
  
  #----------
  # Loop through each node again and draw the connectors
  foreach my $f (keys %Nodes) {
    if (my $pid = $Nodes{$f}->{_parent}) {
      my $xc = $Nodes{$f}->{x} + 2;
      my $yc = $Nodes{$f}->{y} + 2;
      
      my $p = $Nodes{$pid};
      my $xp = $p->{x} + 3;
      my $yp = $p->{y} + 2;
      
      # Connector colour depends on scaling
      my $col = $connector_colours{ ($Nodes{$f}->{_cut} || 0) } || 'red';
      $col = $Nodes{$f}->{_fg_colour} if ($Nodes{$f}->{_fg_colour});

      # Vertical connector
      my $v_line = $self->Line
          ({
            'x'         => $xp,
            'y'         => $yp,
            'width'     => 0,
            'height'    => $yc - $yp,
            'colour'    => $col,
            'zindex'    => 0, 
          });
      $self->push( $v_line );
      
      # Horizontal connector
      my $width = $xc - $xp - 2;
      if( $width ){
        my $h_line = $self->Line
            ({
              'x'         => $xp,
              'y'         => $yc,
              'width'     => $width,
              'height'    => 0,
              'colour'    => $col,
              'zindex'    => 0,
              'dotted' => $Nodes{$f}->{_cut} || undef,
            });
        $self->push( $h_line );
      }
    }
  }

  $self->push( @node_glyphs );
  $self->push(@labels);

  #----------
  # Alignments
  # Display only those gaps that amount to more than 1 pixel on screen, 
  # otherwise screen gets white when you zoom out too much .. 

  # Global alignment settings
  my $fy = $min_y;  
  #my $alignment_start  = $max_x + $labels_bitmap_width + 20;
  #my $alignment_width  = $bitmap_width - $alignment_start;
  my $alignment_start  = $tree_bitmap_width;
  my $alignment_width  = $align_bitmap_width - 20;
  my $alignment_length = 0;

  my @inters = split (/([MmDG])/, $alignments[0]->[1]); # Use first align
  my $ms = 0;
  foreach my $i ( grep { $_ !~ /[MmGD]/} @inters) {
      $ms = $i  || 1;
      $alignment_length  += $ms;
  }
  $alignment_length ||= $alignment_width; # All nodes collapsed
  my $min_length      = int($alignment_length / $alignment_width);   
  my $alignment_scale = $alignment_width / $alignment_length;   
  #warn("==> AL: START: $alignment_start, LENGTH: $alignment_length, ",
  #      "WIDTH: $alignment_width, MIN: $min_length");
  
  foreach my $a (@alignments) {
    my ($yc, $al, $collapsed) = @$a;

    my $box_colour = $collapsed ? 'darkgreen' : 'yellowgreen';

    my $t = $self->Rect({
      'x'         => $alignment_start,
      'y'         => $yc - 3,
      'width'     => $alignment_width,
      'height'    => $font_height,
      'colour'    => $box_colour,
      'zindex' => 0,
    });

    $self->push( $t );


    my @inters = split (/([MmDG])/, $al);
    my $ms = 0;
    my $ds = 0;
    my $box_start = 0;
    my $box_end = 0;
    my $colour = 'white';
    my $zc = 10;
    
    while (@inters) {
      $ms = (shift (@inters) || 1);
      my $mtype = shift (@inters);
      
      $box_end = $box_start + $ms -1;
      
      if ($mtype =~ /G|M/) {
# Skip normal alignment and gaps in alignments
        $box_start = $box_end + 1;
        next;
      }
      
      if ($ms >= $min_length ) { 
        my $t = $self->Rect({
          'x'         => $alignment_start + ($box_start * $alignment_scale),
          'y'         => $yc - 2,
          'z'         => $zc,
          'width'     => abs( $box_end - $box_start + 1 ) * $alignment_scale,
          'height'    => $font_height - 2,
          'colour' => ($mtype eq "m"?"yellowgreen":$colour), 
          'absolutey' => 1,
        });
        
        $self->push($t);
      }
      $box_start = $box_end + 1;
    }
  }

#  warn ("E-0:".localtime());
  return 1;}


sub features {
  my $self = shift;
  my $tree = shift;
  my $rank = shift || 0;
  my $parent_id  = shift || 0;
  my $x_offset = shift  || 0;

  # Scale the branch length
  my $distance = $tree->distance_to_parent;
  my $cut      = 0;
  while ($distance > 1) {
    $distance /= 10;
    $cut ++;
  }
  $x_offset += $distance;

  # Create the feature for this recursion
  my $node_id  = $tree->node_id;
  my @features = ();
  my $f = {
    '_distance'    => $distance,
    '_x_offset'    => $x_offset,
    '_dup'         => $tree->get_tagvalue("Duplication"),
    '_dubious_dup' => $tree->get_tagvalue("dubious_duplication"),
    '_id'          => $node_id, 
    '_rank'        => $rank++,
    '_parent'      => $parent_id,
    '_cut'         => $cut,
  };

  # Initialised colouring
  if( $self->{_fg_coloured_nodes}->{$node_id} ){
    $f->{_fg_colour} = $self->{_fg_coloured_nodes}->{$node_id}->{colour};
  }
  if( $self->{_bg_coloured_nodes}->{$node_id} ){
    $f->{_bg_colour} = $self->{_bg_coloured_nodes}->{$node_id}->{colour};
  }

  # Initialised collapsed nodes
  if( $self->{_collapsed_nodes}->{$node_id} ){
    # What is the size of the collapsed node?
    my $leaf_count = 0;
    my $paralog_count = 0;
    my $sum_dist = 0;
    my %genome_dbs;
    my %genes;
    my %leaves;
    foreach my $leaf( @{$tree->get_all_leaves} ){
      my $dist = $leaf->distance_to_ancestor($tree);
      $leaf_count++;
      $sum_dist += $dist || 0;
      $genome_dbs{$leaf->genome_db->dbID} ++;
      $genes{$leaf->gene_member->stable_id} ++;
      $leaves{$leaf->node_id} ++;
    }
    $f->{_collapsed}          = 1,
    $f->{_collapsed_count}    = $leaf_count;
    $f->{_collapsed_distance} = $sum_dist/$leaf_count;
    $f->{_collapsed_cut}      = 0;
    $f->{_height}             = 12 * log( $f->{_collapsed_count} );
    #while ($f->{_collapsed_distance} > 1) { # Scale the length
    #  $f->{_collapsed_distance} /= 10;
    #  $f->{_collapsed_cut} ++;
    #}
    $f->{_genome_dbs} = {%genome_dbs};
    $f->{_genes}      = {%genes};
    $f->{_leaves}     = {%leaves};
    $f->{label} = sprintf( '%s: %d homologs', 
                           $tree->get_tagvalue('taxon_name'), $leaf_count );
  }
  #----------
  #----------
  # Recurse for each child node
  if (!$f->{_collapsed} and @{$tree->sorted_children}){
    foreach my $child_node (@{$tree->sorted_children}) {  
      $f->{_child_count} ++;
      push( @features, 
            @{$self->features($child_node, $rank, $node_id,$x_offset)} );
    }
  }
  #----------

  # Assign 'y' coordinates
  if ( @features > 0) { # Internal node
    $f->{y} = ($features[0]->{y} + $features[-1]->{y}) / 2;
    $f->{y_from} = $features[0]->{y_from};
    $f->{y_to} = $features[-1]->{y_to};
  } else { # Leaf node or collapsed
    my $height = int( $f->{_height} || 0 ) + 1;
    if( $height < $MIN_ROW_HEIGHT ){ $height = $MIN_ROW_HEIGHT }
    #$f->{y} = ($CURRENT_ROW++) * 20;
    $f->{y} = $CURRENT_Y + ($height/2);
    $f->{y_from} = $CURRENT_Y;
    $CURRENT_Y += $height;
    $f->{y_to} = $CURRENT_Y;
  }

  #----------
  # Process alignment
  if ($tree->isa('Bio::EnsEMBL::Compara::AlignedMember')) {

    if ($tree->genome_db) {
      $f->{_species} = $tree->genome_db->name;
      $f->{_genome_dbs} ||= {};
      $f->{_genome_dbs}->{$tree->genome_db->dbID} ++;
    }
    if ($tree->stable_id) {
      $f->{_protein} = $tree->stable_id;
      $f->{label} = sprintf("%s %s", $f->{_stable_id}, $f->{_species});
    }
    
    if(my $member = $tree->gene_member) {
      my $stable_id = $member->stable_id;
      my $chr_name  = $member->chr_name;
      my $chr_start = $member->chr_start;
      my $chr_end   = $member->chr_end;
      $f->{_gene} = $stable_id;
      $f->{_genes} ||= {};
      $f->{_genes}->{$stable_id} ++;
      
      my $treefam_link = sprintf
          ("http://www.treefam.org/cgi-bin/TFseq.pl?id=%s", $stable_id);
      
      $f->{label} = sprintf("%s %s", $stable_id, $f->{_species});
      push @{$f->{_link}}, { 'text' => 'View in TreeFam', 
                             'href' => $treefam_link };
      $f->{_location}  = sprintf("%s:%d-%d",
                                 $chr_name, 
                                 $chr_start, 
                                 $chr_end);
      $f->{_length}  = $chr_end - $chr_start;
      $f->{_cigar_line} = $tree->cigar_line;
      
      if (my $display_label = $member->display_label) {
        $f->{label} 
        = $f->{_display_id} 
        =  sprintf("%s %s", $display_label, $f->{_species});
      }
    }
  } elsif( $f->{'_collapsed'} ) { # Collapsed node
    $f->{'_name'} = $tree->name;
    if( UNIVERSAL::can($tree, 'consensus_cigar_line' ) ){
      $f->{'_cigar_line'} = $tree->consensus_cigar_line;
    }
  } else { # Internal node
    $f->{'_name'} = $tree->name;
  }
  
  push @features, $f;  
  return \@features;
}

sub colour {
    my ($self, $f) = @_;
    return $f->{colour}, $f->{type} =~ /_snp/ ? 'white' : 'black', 'align';
}

sub image_label { 
  my ($self, $f ) = @_; 
  return $f->seqname(), $f->{type} || 'overlaid'; 
}

#sub zmenu {
#  my( $self, $f ) = @_;
#
#  return( 'gene', $f->{_gene} );
#
#  my $href = '';
#  my $blength = $f->{_cut} ? ($f->{'_distance'} * (10 ** ($f->{'_cut'}))): $f->{'_distance'};
#  my $zmenu = { 
#		caption               => $f->{'_id'},
#		"60:Branch length: $blength"   => '',
#	      };
#
#  $zmenu->{"30:Taxonomy name: $f->{'_name'}"} = '' if ($f->{_name});
#  $zmenu->{"40:Taxonomy ID: $f->{'_taxon_id'}"} = '' if ($f->{_taxon_id});
#  $zmenu->{"45:Dupl. Confidence: $f->{'_dupconf'}"} = '' if ($f->{_dupconf});
#  $zmenu->{"50:Species: $f->{_species}"} = '' if ($f->{_species});
#
#  (my $ensembl_species = $f->{_species}) =~ s/ /\_/g;
#
#  if ($f->{_gene}) {
#      $href = $ensembl_species ? sprintf("/%s/geneview?gene=%s", $ensembl_species, $f->{_gene}) : '';
#      $zmenu->{"10:Gene: $f->{_gene}"} = $href;
#  }
#
#  if ($f->{_protein}) {
#      $zmenu->{"20:Protein: $f->{_protein}"} = $ensembl_species ? sprintf("/%s/protview?peptide=%s", $ensembl_species, $f->{_protein}) : '';
#  }
#
#  $zmenu->{"70:Location: $f->{_location}"} = '' if ($f->{_location});
#
#  warn (Data::Dumper::Dumper($f));
#
#  my $id = 75;
#  foreach my $link (@{$f->{_link}||[]}) {
#      $zmenu->{"$id:".$link->{text}} = $link->{href};
#      $id ++;
#  }
#
##  warn Data::Dumper::Dumper($zmenu);
#
#  return ($zmenu, $href) ;
#}

1;
