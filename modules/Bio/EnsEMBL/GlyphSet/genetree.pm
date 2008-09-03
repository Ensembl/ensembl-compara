package Bio::EnsEMBL::GlyphSet::genetree;

=head1 NAME

EnsEMBL::Web::GlyphSet::genetree;

=head1 SYNOPSIS

The multiple_alignment object handles the basepair display of multiple alignments in alignsliceview.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub fixed { 
  # ...No idea what this method is for...
  return 1;
}


my $CURRENT_ROW;

sub _init {
  # Populate the canvas with feaures represented as glyphs

  my ($self) = @_;

  my $current_gene = $self->{highlights}->[0];
  my $current_genome_db = $self->{highlights}->[1] || ' ';
  my $tree      = $self->{'container'};
  my $Config         = $self->{'config'};
  my $bitmap_length = $Config->image_width(); 



  $CURRENT_ROW = 1;
#  warn ("A-0:".localtime());

  # Create a sorted list of tree nodes sorted by rank then id
  my @nodes = ( sort { ($a->{_rank} <=> $b->{_rank}) * 10  
                           + ( $a->{_id} <=> $b->{_id}) } 
                @{$self->features($tree, 0, 0 ) || [] } );

#  warn ("B-0:".localtime());

  # Calculate space to reserve for the labels
  my( $longest_label ) = ( sort{ length($b) <=> length($a) } 
                           map{$_->{label}} @nodes );
  my( $fontname, $fontsize ) = $self->get_font_details( 'small' );
  my @res = $self->get_text_width( 0, $longest_label, '', 
                                   'font'=>$fontname, 'ptsize' => $fontsize );
  my $font_height = $res[3];
  my $label_width = $res[2];


  # Calculate phylogenetic distance to px scaling
  my $max_distance = $tree->max_distance;
  my $scale = 100;
  if ($max_distance > 10) {
      $scale = 75;
  }
  if ($max_distance > 100) {
      $scale = 50;
  }
  $scale *= ($bitmap_length / 600);
  # warn("SCALE: $bitmap_length | $max_distance | $scale");  
  
  my @alignments;
  my %xcs;

  # Draw each node
  foreach my $f (@nodes) {
      my $xcc = $xcs{$f->{_parent}} + $f->{_distance};
      $xcs{$f->{_id}} = $xcc;

      $f->{x} = $xcc * $scale;

      push @alignments, [ $f->{y} , $f->{_cigar_line} ] if ($f->{_cigar_line});
      my ($zmenu, $href) = $self->zmenu( $f );

      # Node glyph, coloured for for duplication/specition
      my $t = $self->Rect({
	  'x'         => $f->{x},
	  'y'         => $f->{y},
	  'width'     => 5,
	  'height'    => 5,
	  'colour'   => ($f->{_dup} ? 'red3' : 'navyblue'),
	  'zindex'   => ($f->{_dup} ? 40 : -20),
	  'zmenu' => $zmenu
	  });
      $self->push( $t );

      # Leaf label, coloured for focus gene/species
      if ($f->{label}) {
        my $col = $f->{_gene} eq $current_gene 
            ? 'red' 
            : ( $f->{_genome_db} eq $current_genome_db ? 'blue' : 'black');
	  my $txt = $self->Text({
	      'text'       => $f->{label},
	      'height'     => $font_height,
              'width'      => $label_width,
	      'font'       => $fontname,
	      'ptsize'     => $fontsize,
	      'halign' => 'left',
	      'colour'    => $col,
	      'y' => $f->{y} - 3,
	      'x' => $f->{x} + 8,
	      'zindex' => 40,
	      'zmenu' => $zmenu,
	      'href' => $href
	  });

	  $self->push($txt);

      }
 
  }

  my $max_x = (sort {$a->{x} <=> $b->{x}} @nodes)[-1]->{x};
  my $min_y = (sort {$a->{y} <=> $b->{y}} @nodes)[0]->{y};

#  warn ("MAX X: $max_x" );
#  warn ("C-0:".localtime());
#  warn(Data::Dumper::Dumper(\%xcs));
  my %Nodes;
  map { $Nodes{$_->{_id}} = $_} @nodes;

#  warn(Data::Dumper::Dumper(\%Nodes));

  my %Colours = (
		 0 => 'blue',
		 1 => 'blue',
		 2 => 'green',
		 3 => 'red',
		 );

  foreach my $f (keys %Nodes) {
      if (my $pid = $Nodes{$f}->{_parent}) {
	  my $xc = $Nodes{$f}->{x} + 2;
	  my $yc = $Nodes{$f}->{y} + 2;
	  
	  my $p = $Nodes{$pid};
	  my $xp = $p->{x} + 2;
	  my $yp = $p->{y} + 2;
	  
	  my $col = 'blue';

	  $self->unshift( $self->Line({
	      'x'         => $xp,
	      'y'         => $yp,
	      'width'     => 0,
	      'height'    => $yc - $yp,
	      'colour'    => $col,
	      'zindex'    => 0,
	  }));

	  $col = $Colours{ ($Nodes{$f}->{_cut} || 0)} || 'red';

	  $self->unshift( $self->Line({
	      'x'         => $xp,
	      'y'         => $yc,
	      'width'     => $xc - $xp,
	      'height'    => 0,
	      'colour'    => $col,
	      'zindex'    => 0,
	      'dotted' => $Nodes{$f}->{_cut} || undef,
	  }));

      }
  }
#  warn ("D-0:".localtime());
  my $fy = $min_y;

#  warn(Data::Dumper::Dumper(\@alignments));
# Display only those gaps that amount to more than 1 pixel on screen, otherwise screen gets white when you zoom out too much .. 
  
  my $alignment_start = $max_x + $label_width + 20;
  my $alignment_width = $bitmap_length - $alignment_start;
  my @inters = split (/([MDG])/, $alignments[0]->[1]);

  my $alignment_length = 0;
  my $ms = 0;
  foreach my $i ( grep { $_ !~ /[MGD]/} @inters) {
      $ms = $i  || 1;
      $alignment_length  += $ms;
  }

  my $min_length = int($alignment_length / $alignment_width);   
  my $alignment_scale = $alignment_width / $alignment_length;   
#  warn ("AL: $alignment_start, $alignment_length, $alignment_width, $min_length");
  
  foreach my $a (@alignments) {
      my ($yc, $al) = @$a;

      my $t = $self->Rect({
	  'x'         => $alignment_start,
	  'y'         => $yc - 3,
	  'width'     => $alignment_width,
	  'height'    => $font_height,
	  'colour'   => 'yellowgreen',
	  'zindex' => 0,
      });

      $self->push( $t );


      my @inters = split (/([MDG])/, $al);
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
		  'colour' => $colour, 
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

sub features {
  my ($self, $tree, $rank, $pid) = @_;
  $rank ||= 0;
  $pid  ||= 0;

  my @features = ();
  my $f = {
      '_distance' => $tree->distance_to_parent,
      '_dup'      => $tree->get_tagvalue("Duplication"),
      '_id'       => $tree->node_id, 
      '_rank'     => $rank,
      '_parent'   => $pid
  };

  while ($f->{_distance} > 2) {
      $f->{_distance} /= 10;
      $f->{_cut} ++;
  }
	 
  $rank ++;

  my $children = $tree->sorted_children;

  foreach my $child_node (@$children) {  
    push @features, @{$self->features($child_node, $rank, $tree->node_id)};
  }

  if ( @$children > 0) {
      $f->{y} = ($features[0]->{y} + $features[-1]->{y}) / 2;
  } else {
      $f->{y} = ($CURRENT_ROW++) * 20;
      $f->{label} = $f->{_name};
  }

  if ($tree->isa('Bio::EnsEMBL::Compara::AlignedMember')) {

      if ($tree->genome_db) {
        $f->{_species} = $tree->genome_db->name;
	$f->{_genome_db} = $tree->genome_db->dbID;
      }
      if ($tree->stable_id) {
	  $f->{_protein} = $tree->stable_id;
	  $f->{label} = sprintf("%s %s", $f->{_stable_id}, $f->{_species});
      }

      if($tree->gene_member) {
	  $f->{_gene} = $tree->gene_member->stable_id;
	  $f->{label} = sprintf("%s %s", $f->{_gene}, $f->{_species});
	  push @{$f->{_link}}, { 'text' => 'View in TreeFam', 'href' =>  sprintf("http://www.treefam.org/cgi-bin/TFseq.pl?id=%s", $f->{_gene})};
	  $f->{_location}  = sprintf ("%s:%d-%d",$tree->gene_member->chr_name, $tree->gene_member->chr_start, $tree->gene_member->chr_end);
	  $f->{_length}  = $tree->gene_member->chr_end- $tree->gene_member->chr_start;
	  $f->{_cigar_line} = $tree->cigar_line;

	  if (my $display_label = $tree->gene_member->display_label) {
	      $f->{label} = $f->{_display_id} =  sprintf("%s %s", $display_label, $f->{_species});
	  }

#	  if ( $self->{'config'}->{_object}->DBConnection->{'species_defs'}->valid_species($f->{_species}) and
#my $database_spp = $self->{'config'}->{_object}->DBConnection->get_databases_species( $f->{_species}, 'core') ) {
#
#	      my $geneadaptor_spp = $database_spp->{'core'}->get_GeneAdaptor;
#	      if ( my $gene_spp = $geneadaptor_spp->fetch_by_stable_id( $f->{_gene})) {
#		  if (my $display_xref = $gene_spp->display_xref) {
#		      $f->{label} = $f->{_display_id} =  sprintf("%s %s", $display_xref->display_id, $f->{_species});
#
#		  }
#	      }
#	      $database_spp->{'core'}->dbc->disconnect_if_idle();
#	  }
      }
  } else {
      $f->{'_name'} = $tree->name;
      $f->{'_taxon_id'} = $tree->get_tagvalue('taxon_id');
      $f->{'_dupconf'} = $tree->get_tagvalue('duplication_confidence_score');
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

sub zmenu {
  my( $self, $f ) = @_;

  my $href = '';
  my $blength = $f->{_cut} ? ($f->{'_distance'} * (10 ** ($f->{'_cut'}))): $f->{'_distance'};
  my $zmenu = { 
		caption               => $f->{'_id'},
		"60:Branch length: $blength"   => '',
	      };

  $zmenu->{"30:Taxonomy name: $f->{'_name'}"} = '' if ($f->{_name});
  $zmenu->{"40:Taxonomy ID: $f->{'_taxon_id'}"} = '' if ($f->{_taxon_id});
  $zmenu->{"45:Dupl. Confidence: $f->{'_dupconf'}"} = '' if ($f->{_dupconf});
  $zmenu->{"50:Species: $f->{_species}"} = '' if ($f->{_species});

  (my $ensembl_species = $f->{_species}) =~ s/ /\_/g;

  if ($f->{_gene}) {
      $href = $ensembl_species ? sprintf("/%s/geneview?gene=%s", $ensembl_species, $f->{_gene}) : '';
      $zmenu->{"10:Gene: $f->{_gene}"} = $href;
  }

  if ($f->{_protein}) {
      $zmenu->{"20:Protein: $f->{_protein}"} = $ensembl_species ? sprintf("/%s/protview?peptide=%s", $ensembl_species, $f->{_protein}) : '';
  }

  $zmenu->{"70:Location: $f->{_location}"} = '' if ($f->{_location});

#  warn (Data::Dumper::Dumper($f));

  my $id = 75;
  foreach my $link (@{$f->{_link}||[]}) {
      $zmenu->{"$id:".$link->{text}} = $link->{href};
      $id ++;
  }

#  warn Data::Dumper::Dumper($zmenu);

  return ($zmenu, $href) ;
}

1;
