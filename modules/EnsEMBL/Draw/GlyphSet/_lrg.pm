=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::_lrg;

### STATUS : Unknown - not clear if still in use

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

use Bio::EnsEMBL::LRGSlice;

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};

  my $db_alias = $self->my_config('db');
  my $analyses = $self->my_config('logic_names');
  my @T =@{$slice->get_all_Genes( $_, $db_alias )||[]};


  my @T2;


  warn join ' * ', 'SLICE', $slice->seq_region_name, $slice->start, $slice->end;
  foreach my $lrg_name (@{$self->species_defs->LRG_REGIONS || []}) {
      my $lrg =$slice->adaptor->fetch_by_region( undef, $lrg_name) || next;
     warn join ' * ', 'LRG', $lrg->feature_Slice->seq_region_name, $lrg->feature_Slice->start, $lrg->feature_Slice->end, "\n";
      my $chr_slice = $lrg->feature_Slice || next;
      if ( $slice->seq_region_name eq $chr_slice->seq_region_name) {
	  if (($slice->start < $chr_slice->end) && ($chr_slice->start < $slice->end)) {
	      push @T2, $lrg;
	  }
      }
#      warn join ' * ', $lrg, sort keys (%$lrg);
#      foreach my $k (sort keys (%$lrg)) {
#	  warn "$k => $lrg->{$k} \n";
#      }


  }

#  warn "LRG C : ", scalar(@T2), "\n";
  return \@T2;

  return \@T;
}

sub render_gene_nolabel { $_[0]->_init(0); }
sub render_gene_label   { $_[0]->_init(1); }

sub _init {
  my $self = shift;

  return unless ($self->strand() == -1);

  my $vc             = $self->{'container'};
  my $type           = $self->type;
  my $h              = 8;
  
  my $FONT           = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
  my $FONTSIZE       = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONTSIZE'} *
                       $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_OUTERTEXT'};

  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  $self->_init_bump();
  my $vc_length      = $vc->length;
  my $pix_per_bp     = $self->scalex;

  my $navigation     = $self->my_config('navigation') || 'on';
  my $show_navigation = $navigation eq 'on' ? 1 : 0; # && ( $vc->length() < $max_length_nav * 1001 );
   
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

  my $regions = $self->features();
  foreach my $g (@{$regions || []}) {
    my $gene_col   = 'skyblue3'; 
    my $label      = $g->seq_region_name;
    my $high = $g->seq_region_name eq $self->{'config'}->core_object('parameters')->{'lrg'};

    my $gslice = $g->feature_Slice;

    my $start = $gslice->start - $vc->start;
    my $end   = $gslice->end - $vc->start;
    my ($chr_start, $chr_end) = ( $gslice->start, $gslice->end );

    warn "CHR : $chr_start * $chr_end * $start * $end\n";
    my ($chr_start, $chr_end) = ( $start, $end );
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

    $rect->{'title'} = "LRG: ".$g->seq_region_name."; Location: ".
                       $gslice->seq_region_name.':'.$gslice->start.'-'.$gslice->end;
    if($show_navigation) {
      $rect->{'href'}  = $self->_url({'type'=>'LRG','action'=>'Summary','lrg'=>$g->seq_region_name,'db'=>$database});
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
       $GL_FLAG = 1 if $GL_FLAG eq '';
       $GL_FLAG = shift if @_;
       $GL_FLAG = 0 if ( $self->my_config( 'label_threshold' ) || 50e3 )*1001 < $vc->length;
    if( $GL_FLAG ) {
      my $START_ROW = $self->_max_bump_row+1;
      $self->_init_bump;
my($a,$b,$c,$H) = $self->get_text_width( 0,'X_y','','font'=>$FONT,'ptsize'=>$FONTSIZE);

      foreach my $gr ( @GENES_TO_LABEL ) {
        my( $txt, $part, $W, $H2 ) = $self->get_text_width( 0, "$gr->{'label'} ", '', 'font' => $FONT, 'ptsize' => $FONTSIZE );
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
          'title'     => $gr->{'title'},
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
  }
}


sub old_init {
  my $self = shift;

  return unless ($self->strand() == -1);

  my $vc             = $self->{'container'};
  my $type           = $self->type;
  my $h              = 8;
  
  my $FONT           = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
  my $FONTSIZE       = $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONTSIZE'} *
                       $self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_OUTERTEXT'};

  my %highlights;
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  $self->_init_bump();
  my $vc_length      = $vc->length;
  my $pix_per_bp     = $self->scalex;

  my $navigation     = $self->my_config('navigation') || 'on';
  my $show_navigation = $navigation eq 'on' ? 1 : 0; # && ( $vc->length() < $max_length_nav * 1001 );
   
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
    my $gene_col   = 'skyblue3'; 
    my $label      = $g->external_name || $g->stable_id;
    my $high = $g->stable_id eq $self->{'config'}->core_object('parameters')->{'g'};

    my $start = $g->start;
    my $end   = $g->end;
    my ($chr_start, $chr_end) = $self->slice2sr( $start, $end );
    warn join ' * ' , 'CHR', $chr_start, $chr_end, $start, $end ;
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
                       "LRG: ".$g->stable_id."; Location: ".
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
       $GL_FLAG = 1 if $GL_FLAG eq '';
       $GL_FLAG = shift if @_;
       $GL_FLAG = 0 if ( $self->my_config( 'label_threshold' ) || 50e3 )*1001 < $vc->length;
    if( $GL_FLAG ) {
      my $START_ROW = $self->_max_bump_row+1;
      $self->_init_bump;
my($a,$b,$c,$H) = $self->get_text_width( 0,'X_y','','font'=>$FONT,'ptsize'=>$FONTSIZE);

      foreach my $gr ( @GENES_TO_LABEL ) {
        my( $txt, $part, $W, $H2 ) = $self->get_text_width( 0, "$gr->{'label'} ", '', 'font' => $FONT, 'ptsize' => $FONTSIZE );
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
          'title'     => $gr->{'title'},
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
