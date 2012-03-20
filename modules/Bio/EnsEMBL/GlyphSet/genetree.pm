package Bio::EnsEMBL::GlyphSet::genetree;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub fixed { 
  # ...No idea what this method is for...
  return 1;
}

# Colours of connectors; affected by scaling
my %connector_colours = (
                         0 => 'blue',
                         1 => 'blue',
                         2 => 'green',
                         3 => 'red',
                         );

my $CURRENT_ROW;
my $CURRENT_Y;
my $MIN_ROW_HEIGHT = 20;
my $EXON_TICK_SIZE = 4;
my $EXON_TICK_COLOUR = "#333333";

sub _init {
  # Populate the canvas with feaures represented as glyphs
  my ($self) = @_;

  my $current_gene          = $self->{highlights}->[0];
  my $current_genome_db_id  = $self->{highlights}->[1] || ' ';
  my $collapsed_nodes_str   = $self->{highlights}->[2] || '';
  my $coloured_nodes        = $self->{highlights}->[3] || [];
  my $other_genome_db_id    = $self->{highlights}->[4];
  my $other_gene            = $self->{highlights}->[5];
  my $highlight_ancestor    = $self->{highlights}->[6];
  my $show_exons            = $self->{highlights}->[7];
  my $tree          = $self->{'container'};
  my $Config        = $self->{'config'};
  my $bitmap_width = $Config->image_width(); 

  my $cdb = $Config->get_parameter('cdb');
  my $skey = $cdb =~ /pan/ ? "_pan_compara" : '';

  $CURRENT_ROW = 1;
  $CURRENT_Y   = 1;
#  warn ("A-0:".localtime());

  # Handle collapsed/removed nodes
  my %collapsed_nodes = ( map{$_=>1} split( ',', $collapsed_nodes_str ) );  
  $self->{_collapsed_nodes} = \%collapsed_nodes;

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
                @{$self->features($tree, 0, 0, 0, $show_exons ) || [] } );

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


  
  # Draw each node
  my %Nodes;
  map { $Nodes{$_->{_id}} = $_} @nodes;
  my @alignments;
  my @node_glyphs;
  my @bg_glyphs;
  my @labels;
#  use Data::Dumper;
  foreach my $f (@nodes) {
     # Ensure connector enters at base of node glyph
    my $parent_node = $Nodes{$f->{_parent}} || {x=>0};
    my $min_x = $parent_node->{x} + 4;
    ($f->{x}) = sort{$b<=>$a} int($f->{_x_offset} * $nodes_scale), $min_x;
    
    if ($f->{_cigar_line}){
      push @alignments, [ $f->{y} , $f->{_cigar_line}, $f->{_collapsed}, $f->{_aligned_exon_lengths}] ;
    }
    
    # Node glyph, coloured for for duplication/speciation
    my ($node_colour, $label_colour, $collapsed_colour, $bold);
    my $bold_colour = "white";
    if ($f->{_node_type} eq 'duplication') {
      $node_colour = 'red3';
    } elsif ($f->{_node_type} eq 'dubious') {
      $node_colour = 'turquoise';
    } elsif ($f->{_node_type} eq 'gene_split') {
      $node_colour = 'SandyBrown';
    }

    if ($f->{label}) {
      if( $f->{_genes}->{$other_gene} ){
        $bold = 1;
        $bold_colour = "ff6666";
      } elsif( $f->{_genome_dbs}->{$other_genome_db_id} ){
        $bold = 1;
      } elsif( $f->{_genes}->{$current_gene} ){
        $label_colour     = 'red';
        $collapsed_colour = 'red';
        $node_colour = "royalblue";
        $bold = defined($other_genome_db_id);
      } elsif( $f->{_genome_dbs}->{$current_genome_db_id} ){
        $label_colour     = 'blue';
        $collapsed_colour = 'royalblue';
        $bold = defined($other_genome_db_id);
      }
    }
    if ($f->{_fg_colour}) {
      # Use this foreground colour for this node if not already set
      $node_colour = $f->{_fg_colour} if (!$node_colour);
      $label_colour = $f->{_fg_colour} if (!$label_colour);
      $collapsed_colour = $f->{_fg_colour} if (!$collapsed_colour);
    }
    if ($highlight_ancestor and $highlight_ancestor == $f->{'_id'}) {
      $bold = 1;
    }
    $node_colour = "navyblue" if (!$node_colour); # Default colour
    $label_colour = "black" if (!$label_colour); # Default colour
    $collapsed_colour = 'grey' if (!$collapsed_colour); # Default colour

    my $node_href = $self->_url({ 
      action      => "ComparaTreeNode$skey",
      node        => $f->{'_id'},
      genetree_id => $Config->get_parameter('genetree_id'),
      collapse    => $collapsed_nodes_str
    });

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
      if ($f->{_node_type} eq 'gene_split') {
        push @node_glyphs, Sanger::Graphics::Glyph::Rect->new
            ({
              'x'         => $f->{x},
              'y'         => $f->{y},
              'width'     => 5,
              'height'    => 5,
              'bordercolour' => 'navyblue',
              'href'      => $node_href,
            });
      }

    }
    elsif( $f->{_child_count} ){ # Expanded internal node
      # Add a 'collapse' href
      my $node_glyph = Sanger::Graphics::Glyph::Rect->new
          ({
            'x'         => $f->{x} - $bold,
            'y'         => $f->{y} - $bold,
            'width'     => 5 + 2 * $bold,
            'height'    => 5 + 2 * $bold,
            'colour'    => $node_colour,
            'zindex'    => ($f->{_node_type} ne 'speciation' ? 40 : -20),
            'href'      => $node_href
          });
      push @node_glyphs, $node_glyph;
      if ($bold) {
        my $node_glyph = Sanger::Graphics::Glyph::Rect->new
            ({
              'x'         => $f->{x},
              'y'         => $f->{y},
              'width'     => 5,
              'height'    => 5,
              'bordercolour' => "white",
              'zindex'    => ($f->{_node_type} ne 'speciation' ? 40 : -20),
              'href'      => $node_href
            });
        push @node_glyphs, $node_glyph;
      }
      if ($f->{_node_type} eq 'gene_split') {
        push @node_glyphs, Sanger::Graphics::Glyph::Rect->new
            ({
              'x'         => $f->{x},
              'y'         => $f->{y},
              'width'     => 5,
              'height'    => 5,
              'bordercolour' => 'navyblue',
              'zindex'    => -20,
              'href'      => $node_href,
            });
      }

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

      if ($bold) {
        for (my $delta_x = -1; $delta_x <= 1; $delta_x++) {
          for (my $delta_y = -1; $delta_y <= 1; $delta_y++) {
            next if ($delta_x == 0 and $delta_y == 0);
            my %txt2 = %$txt;
            bless(\%txt2, ref($txt));
            $txt2{x} += $delta_x;
            $txt2{y} += $delta_y;
            push(@labels, \%txt2);
          }
        }
        $txt->{colour} = $bold_colour;
      }
      
      if ($f->{'_gene'}) {
        $txt->{'href'} = $self->_url({
          species  => $f->{'_species'},
          type     => 'Gene',
          action   => 'ComparaTree',
          __clear  => 1,
          g        => $f->{'_gene'}
        });
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
  # DRAW THE TREE CONNECTORS
  $self->_draw_tree_connectors(%Nodes);


  # Push the nodes afterwards, so they show above the connectors
  $self->push( @node_glyphs );
  $self->push(@labels);

  #----------
  # DRAW THE ALIGNMENTS
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
    my ($yc, $al, $collapsed, $exon_lengths) = @$a;

    # Draw the exon splits under the boxes
    my $exon_end = 0;
    foreach my $exon_length (@$exon_lengths) {
      $exon_end += $exon_length;
      my $e = $self->Line({
        'x'         => $alignment_start + $exon_end * $alignment_scale,
        'y'         => $yc - 3 - $EXON_TICK_SIZE,
        'width'     => 0,
        'height'    => $font_height + (2 * $EXON_TICK_SIZE),
        'colour'    => $EXON_TICK_COLOUR,
        'zindex' => 0,
      });

      $self->push( $e );
    }

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
  return 1;
}

sub _draw_tree_connectors {
  my ($self, %Nodes) = @_;

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
}

sub features {
  my $self       = shift;
  my $tree       = shift;
  my $rank       = shift || 0;
  my $parent_id  = shift || 0;
  my $x_offset   = shift || 0;
  my $show_exons = shift || 0;

  # Scale the branch length
  my $distance = $tree->distance_to_parent;
  my $cut      = 0;
  
  while ($distance > 1) {
    $distance /= 10;
    $cut++;
  }
  
  $x_offset += $distance;

  # Create the feature for this recursion
  my $node_id  = $tree->node_id;
  my @features;
  
  my $f = {
    _distance    => $distance,
    _x_offset    => $x_offset,
    _node_type   => $tree->get_tagvalue('node_type'),
    _id          => $node_id, 
    _rank        => $rank++,
    _parent      => $parent_id,
    _cut         => $cut,
  };
  
  # Initialised colouring
  $f->{'_fg_colour'} = $self->{'_fg_coloured_nodes'}->{$node_id}->{'colour'} if $self->{'_fg_coloured_nodes'}->{$node_id};
  $f->{'_bg_colour'} = $self->{'_bg_coloured_nodes'}->{$node_id}->{'colour'} if $self->{'_bg_coloured_nodes'}->{$node_id};

  # Initialised collapsed nodes
  if ($self->{'_collapsed_nodes'}->{$node_id}) {
    # What is the size of the collapsed node?
    my $leaf_count    = 0;
    my $paralog_count = 0;
    my $sum_dist      = 0;
    my %genome_dbs;
    my %genes;
    my %leaves;
    
    foreach my $leaf (@{$tree->get_all_leaves}) {
      my $dist = $leaf->distance_to_ancestor($tree);
      $leaf_count++;
      $sum_dist += $dist || 0;
      $genome_dbs{$leaf->genome_db->dbID}++;
      $genes{$leaf->gene_member->stable_id}++;
      $leaves{$leaf->node_id}++;
    }
    
    $f->{'_collapsed'}          = 1,
    $f->{'_collapsed_count'}    = $leaf_count;
    $f->{'_collapsed_distance'} = $sum_dist/$leaf_count;
    $f->{'_collapsed_cut'}      = 0;
    $f->{'_height'}             = 12 * log($f->{'_collapsed_count'});
    $f->{'_genome_dbs'}         = \%genome_dbs;
    $f->{'_genes'}              = \%genes;
    $f->{'_leaves'}             = \%leaves;
    $f->{'label'}               = sprintf '%s: %d homologs', $tree->get_tagvalue('taxon_name'), $leaf_count;
  }
  
  # Recurse for each child node
  if (!$f->{'_collapsed'} && @{$tree->sorted_children}) {
    foreach my $child_node (@{$tree->sorted_children}) {  
      $f->{'_child_count'}++;
      push @features, @{$self->features($child_node, $rank, $node_id, $x_offset, $show_exons)};
    }
  }

  # Assign 'y' coordinates
  if (@features > 0) { # Internal node
    $f->{'y'}      = ($features[0]->{'y'} + $features[-1]->{'y'}) / 2;
    $f->{'y_from'} = $features[0]->{'y_from'};
    $f->{'y_to'}   = $features[-1]->{'y_to'};
  } else { # Leaf node or collapsed
    my $height = int($f->{'_height'} || 0) + 1;
    $height    = $MIN_ROW_HEIGHT if $height < $MIN_ROW_HEIGHT;
    
    $f->{'y'}      = $CURRENT_Y + ($height/2);
    $f->{'y_from'} = $CURRENT_Y;
    
    $CURRENT_Y += $height;
    
    $f->{'y_to'} = $CURRENT_Y;
  }
  
  # Process alignment
  if ($tree->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    if ($tree->genome_db) {
      $f->{'_species'} = ucfirst $tree->genome_db->name; # This will be used in URLs

      # This will be used for display
      $f->{'_species_label'} = $self->species_defs->get_config($f->{'_species'}, 'SPECIES_SCIENTIFIC_NAME') || $self->species_defs->species_label($f->{'_species'}) || $f->{'_species'}; 
      $f->{'_genome_dbs'} ||= {};
      $f->{'_genome_dbs'}->{$tree->genome_db->dbID}++;
    }
    
    if ($tree->stable_id) {
      $f->{'_protein'} = $tree->stable_id;
      $f->{'label'}    = "$f->{'_stable_id'} $f->{'_species_label'}";
    }
    
    if (my $member = $tree->gene_member) {
      my $stable_id = $member->stable_id;
      my $chr_name  = $member->chr_name;
      my $chr_start = $member->chr_start;
      my $chr_end   = $member->chr_end;
      
      $f->{'_gene'} = $stable_id;
      $f->{'_genes'} ||= {};
      $f->{'_genes'}->{$stable_id}++;
      
      my $treefam_link = "http://www.treefam.org/cgi-bin/TFseq.pl?id=$stable_id";
      
      $f->{'label'} = "$stable_id, $f->{'_species_label'}";
      
      push @{$f->{'_link'}}, { text => 'View in TreeFam', href => $treefam_link };
      
      $f->{'_location'}   = "$chr_name:$chr_start-$chr_end";
      $f->{'_length'}     = $chr_end - $chr_start;
      $f->{'_cigar_line'} = $tree->cigar_line;
      
      if ($show_exons) {
        eval {
          my $aligned_sequences_bounded_by_exon = $tree->alignment_string_bounded;
          my (@bounded_exons) = split ' ', $aligned_sequences_bounded_by_exon;
          pop @bounded_exons;
          
          $f->{'_aligned_exon_lengths'} = [ map length($_), @bounded_exons ];
        };
      }
      
      if (my $display_label = $member->display_label) {
        $f->{'label'} = $f->{'_display_id'} = "$display_label, $f->{'_species_label'}";
      }
    }
  } elsif ($f->{'_collapsed'}) { # Collapsed node
    $f->{'_name'}       = $tree->name;
    $f->{'_cigar_line'} = $tree->consensus_cigar_line if UNIVERSAL::can($tree, 'consensus_cigar_line');
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

1;
