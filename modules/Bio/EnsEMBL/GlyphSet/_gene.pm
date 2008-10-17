package Bio::EnsEMBL::GlyphSet::_gene;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};

  my $db_alias = $self->my_config('db');
  my $analyses = $self->my_config('logicnames');
  my @T = map { @{$slice->get_all_Genes( $_, $db_alias )||[]} } @$analyses;
  return \@T;
}

sub _init {
  my ($self) = @_;

  return unless ($self->strand() == -1);

  my $vc             = $self->{'container'};
  my $type           = $self->check();
  my $h              = 8;
  
  my $FONT           = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
  my $FONTSIZE       = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONTSIZE'} *
                       $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_OUTERTEXT'};

  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  $self->_init_bump();
  my $vc_length      = $vc->length;
  my $pix_per_bp     = $self->scalex;

  my $max_length     = $self->my_config('threshold') || 1e6;
  my $max_length_nav = $self->my_config('navigation_threshold') || 50e3;
  my $navigation     = $self->my_config('navigation') || 'on';

  if( $vc_length > ($max_length*1001)) {
    $self->errorTrack("Genes only displayed for less than $max_length Kb.");
    return;
  }
  my $show_navigation = $navigation eq 'on' && ( $vc->length() < $max_length_nav * 1001 );
   
  #First of all let us deal with all the EnsEMBL genes....
  my $offset = $vc->start - 1;

  my %gene_objs;

  my $F = 0;

  my $fontname = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'}; # "Small";
  my $database = $self->my_config( 'db' );

  my $used_colours = {};
  my $FLAG = 0;
## We need to store the genes to label...
  my @GENES_TO_LABEL = ();

  my $genes = $self->features();
  foreach my $g (@$genes) {
    my $gene_key   = $self->gene_key( $g );
    my $gene_col   = $self->my_colour( $gene_key );

    my $gene_type  = $self->my_colour( $gene_key, 'text' );
    my $label      = $g->external_name || $g->stable_id;
#    my $high = exists $highlights{ lc($gene_label) } || exists $highlights{ lc($g->stable_id) };
    my $high = $g->stable_id eq $self->{'config'}{'_core'}{'parameters'}{'g'};

    my $start = $g->start;
    my $end   = $g->end;
    my ($chr_start, $chr_end) = $self->slice2sr( $start, $end );
    next if  $end < 1 || $start > $vc_length;
    $start = 1 if $start<1;
    $end   = $vc_length if $end > $vc_length;

    my $HREF;
    my $rect = $self->Rect({
      'x'         => $start-1,
      'y'         => 0,
      'width'     => $end - $start+1,
      'height'    => $h,
      'colour'    => $gene_col,
      'absolutey' => 1,
    });

    $rect->{'title'} = ( $g->external_name ? $g->external_name.'; ':'' ).
                       "Gene: ".$g->stable_id."; Location: ".
                       $g->seq_region_name.':'.$g->seq_region_start.'-'.$g->seq_region_end;
    if($show_navigation) {
      $rect->{'href'}  = $self->_url({'type'=>'Gene','action'=>'Summary','g'=>$g->stable_id,'db'=>$database});
    }
    push @GENES_TO_LABEL , {
      'start'     => $start,
      'label'     => $label,
      'end'       => $end,
      'href'      => $rect->{'href'},
      'title'     => $rect->{'title'},
      'gene'      => $g,
      'col'       => $gene_col,
      'highlight' => $high
    };
    my $bump_start = int($rect->x() * $pix_per_bp);
    my $bump_end = $bump_start + int($rect->width()*$pix_per_bp) +1;
    my $row = $self->bump_row( $bump_start, $bump_end );
    $rect->y($rect->y() + (6 * $row ));
    $rect->height(4);
    $self->push($rect);
    $self->unshift($self->Rect({
      'x'         => $start -1 - 1/$pix_per_bp,
      'y'         => $rect->y()-1,
      'width'     => $end - $start  +1 + 2/$pix_per_bp,
      'height'    => $rect->height()+2,
      'colour'    => 'highlight2',
      'absolutey' => 1,
    })) if $high;
    $FLAG=1;
  } 
  if($FLAG) { ## NOW WE NEED TO ADD THE LABELS_TRACK.... FOLLOWED BY THE LEGEND
    my $GL_FLAG = $self->get_parameter(  'opt_gene_labels' );
       $GL_FLAG = 1 unless defined($GL_FLAG);
       $GL_FLAG = 0 if ( $self->my_config( 'label_threshold' ) || 50e3 )*1001 < $vc->length;
    if( $GL_FLAG ) {
      my $START_ROW = $self->_max_bump_row+1;
      $self->_init_bump;
      foreach my $gr ( @GENES_TO_LABEL ) {
        my( $txt, $part, $W, $H ) = $self->get_text_width( 0, "$gr->{'label'} ", '', 'font' => $FONT, 'ptsize' => $FONTSIZE );
        my $tglyph = $self->Text({
          'x'         => $gr->{'start'}-1 + 4/$pix_per_bp,
          'y'         => 0,
          'height'    => $H,
          'width'     => $W / $pix_per_bp,
          'font'      => $FONT,
          'halign'    => 'left',
          'ptsize'    => $FONTSIZE,
          'colour'    => $gr->{'col'},
          'text'      => "$gr->{'label'}",
          'zmenu'     => $gr->{'zmenu'},
          'href'      => $gr->{'href'},
          'absolutey' => 1,
        });
        my $bump_start = int($tglyph->{'x'} * $pix_per_bp) - 4;
        my $bump_end = $bump_start + int($tglyph->width()*$pix_per_bp) +1;
        my $row = $self->bump_row( $bump_start, $bump_end );
        $tglyph->y($tglyph->{'y'} + $row * (2+$H) + ($START_ROW-1) * 6);
        $self->push(
	  $tglyph,
    # Draw little taggy bit to indicate start of gene
          $self->Rect({
            'x'            => $gr->{'start'}-1,
            'y'            => $tglyph->y + 2,
            'width'        => 0,
            'height'       => 4,
            'bordercolour' => $gr->{'col'},
            'absolutey'    => 1,
          }),
          $self->Rect({
            'x'            => $gr->{'start'}-1,
            'y'            => $tglyph->y + 2 + 4,
            'width'        => 3/$pix_per_bp,
            'height'       => 0,
            'bordercolour' => $gr->{'col'},
            'absolutey'    => 1,
          })
	);
        $self->unshift($self->Rect({
          'x'         => $gr->{'start'}-1 - 1/$pix_per_bp,
          'y'         => $tglyph->y()+1,
          'width'     => $tglyph->width()  +1 + 2/$pix_per_bp,
          'height'    => $tglyph->height()+2,
          'colour'    => 'highlight2',
          'absolutey' => 1,
        })) if $gr->{'highlight'};
      }
    }
    #$Config->{'legend_features'}->{$type} = {
#      'priority' => $Config->get( $type, 'pos' ),
#      'legend'  => $self->legend( $used_colours )
#    };
  }
}

sub legend {
  my( $self, $colours ) = @_;
  my @legend = ();
  my %X;
  foreach my $Y ( values %$colours ) { $X{$Y->[1]} = $Y->[0]; }
  my @legend = %X;
  return \@legend;
}

1;
