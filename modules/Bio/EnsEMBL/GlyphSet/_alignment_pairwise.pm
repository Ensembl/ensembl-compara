package Bio::EnsEMBL::GlyphSet::_alignment_pairwise;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub colour   { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }

sub render_normal {
  my $self           = shift;

  my $WIDTH          = 1e5;
  my $container      = $self->{'container'};
  my $strand         = $self->strand();
  my $strand_flag    = $self->my_config('strand');
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand !=  1;

  my $caption        = $self->my_config('caption');
  my $depth          = $self->my_config('depth') || 6;
  $self->_init_bump( undef, $depth );  ## initialize bumping!!

  my %highlights; @highlights{$self->highlights()} = ();

  my $length         = $container->length;
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = $pix_per_bp > 0.2 ;
  my $feature_key    = lc( $self->my_config('type') );
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key,'join'  ) || 'gold'; 
  my $join_z         = $self->my_colour($feature_key,'join_z') || 100;
  warn "... $feature_key [$feature_colour / $join_col / $join_z] ....";
  my %id             = ();
  my $small_contig   = 0;
  my $h              = $self->get_parameter( 'opt_halfheight') ? 4 : 8;
  my $chr            = $self->{'container'}->seq_region_name;
  my $other_species  = $self->my_config('species' );
  my $species_2      = $self->my_config('species_hr');
  my $self_species   = $container->{web_species};
  my $compara        = $self->get_parameter('compara');
  my $link = 0;
  my $TAG_PREFIX;
  my $METHOD         = $self->my_config('method' );
#  warn "expanded method is $METHOD";

  if( $compara) {
    $link = $self->my_config('join');
    $TAG_PREFIX  = uc( $compara eq 'primary' ? 
                       join ( '_', $METHOD, $self_species, $other_species ) :
                       join ( '_', $METHOD, $other_species, $self_species ) );
  } 
  my $C = 0; ## Diagnostic counters....
  my $K = 0;

  warn ">>>>> $other_species $METHOD in expanded init<<<<<";
  foreach my $f ( @{$self->features||[]} ){
    next if $strand_flag eq 'b' && $strand != $f->hstrand || $f->end < 1 || $f->start > $length ;
    push @{$id{$f->hseqname().':'. ($f->group_id||("00".$K++)) }}, [$f->start,$f];
  }


## Now go through each feature in turn, drawing them
  my @glyphs;
  my $BLOCK = 0;
  my $script = $ENV{'ENSEMBL_SCRIPT'} eq 'multicontigview' ? 'contigview' : $ENV{'ENSEMBL_SCRIPT'};
  my $SHORT = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self->my_config( 'species' ) };
  my $domain = $self->my_config( 'linkto' );
  my $HREF  = $self->my_config(  'linkto' )."/$SHORT/$script";

  # sort alignments by size
  my @s_i = sort {($id{$b}[0][1]->hend() - $id{$b}[0][1]->hstart()) <=> ($id{$a}[0][1]->hend() - $id{$a}[0][1]->hstart())} keys %id;
  foreach my $i (@s_i){
    my @F = sort { $a->[0] <=> $b->[0] } @{$id{$i}};

    my( $seqregion,$group ) = split /:/, $i;
    my $START = $F[0][0] < 1 ? 1 : $F[0][0];
    my $END   = $F[-1][1]->end > $length ? $length : $F[-1][1]->end;
    my $start = $F[0][1]->hstart();
    my $end   = $F[0][1]->hend();
    my $bump_start = int($START * $pix_per_bp) -1 ;
    my $bump_end   = int($END * $pix_per_bp);
    my $row = $self->bump_row( $bump_start, $bump_end );
    next if $row > $depth;
    my $y_pos = - $row * int( 1.5 * $h ) * $strand;
    my $Composite = $self->Composite({
      'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
      'width' => 0,
      'y' => 0
    });
    my $X = -1000000;
    foreach  ( @F ){
      my $f = $_->[1];
      $start = $f->hstart() if $f->hstart < $start;
      $end   = $f->hend()   if $f->hend   > $end;
      next if int($f->end * $pix_per_bp) <= int( $X * $pix_per_bp );
      $C++;
      if($DRAW_CIGAR) {
        $self->draw_cigar_feature($Composite, $f, $h, $feature_colour, 'black', $pix_per_bp, 1 );
      } else {
        my $START = $_->[0] < 1 ? 1 : $_->[0];
        my $END   = $f->end > $length ? $length : $f->end;
        $X = $END;
        my $BOX = $self->Rect({
          'x'          => $START-1,
          'y'          => 0,
          'width'      => $END-$START+1,
          'height'     => $h,
          'colour'     => $feature_colour,
          'absolutey'  => 1,
        });
        if( $strand_flag eq 'z' && $join_col) {
          $self->join_tag( $BOX, "BLOCK_".$self->_type."$BLOCK", $strand == -1 ? 0 : 1, 0 , $join_col, 'fill', $join_z ) ;
          $self->join_tag( $BOX, "BLOCK_".$self->_type."$BLOCK", $strand == -1 ? 1 : 0, 0 , $join_col, 'fill', $join_z ) ;
          $BLOCK++;
        }
        $Composite->push($BOX);
      }
    }
    if( ($compara eq 'primary' || $compara eq 'secondary') && $link ) {
      my $Z = $strand == -1 ? 1 : 0;
      foreach( @F ) {
        my $f = $_->[1];
        my( $start, $end, $start2,$end2) = ( $f->hstart, $f->hend, $f->start, $f->end );
        my( $start3, $end3 ) = $self->slice2sr( $start2, $end2 );
        my $S = $start2 < $Composite->x ? 0 : ( $start2 - $Composite->x ) / $Composite->width;
        my $E = $end2   > $Composite->x+$Composite->width ? 1 : ( $end2 - $Composite->x ) / $Composite->width;
        if( $strand != -1 ) {
          my $TAG = $self->{'config'}{'slice_id'}."$TAG_PREFIX.$start.$end:$start3.$end3.$strand";
          $self->join_tag( $Composite, $TAG, $S, $Z, $join_col, 'fill', $join_z );
          $self->join_tag( $Composite, $TAG, $E, $Z, $join_col, 'fill', $join_z );
        } else {
          my $TAG = ($self->{'config'}{'slice_id'}+1)."$TAG_PREFIX.$start3.$end3:$start.$end.".(-$strand);
          $self->join_tag( $Composite, $TAG, $E, $Z, $join_col, 'fill', $join_z );
          $self->join_tag( $Composite, $TAG, $S, $Z, $join_col, 'fill', $join_z );
        }
      }
    }
    $Composite->y( $Composite->y + $y_pos );
    $Composite->bordercolour($feature_colour);
    my $ZZ;
    if($end-$start<$WIDTH) {
      my $X =int(( $start + $end - $WIDTH) /2);
      my $Y = $X + $WIDTH ;
      $ZZ = "l=$seqregion:$X-$Y";
    } else {
      $ZZ = "l=$seqregion:$start-$end";
    }
    $Composite->href(  "$HREF?$ZZ" );

    my $orient = ($F[0][1]->hstrand * $F[0][1]->strand > 0) ? 'Forward' : 'Reverse';
    my $chr_2   = $F[0][1]->hseqname;
    my $zmenu = {
      'type'     => 'Location',
      'action'   => 'ComparaGenomicAlignment',
#      'r'        => "$chr:$start-$end",
      'r1'       => "$chr_2:$start-$end",
      's1'       => $other_species,
      'orient'   => $orient,
    };

    if(exists $highlights{$i}) {
      $self->unshift($self->Rect({
        'x'         => $Composite->x() - 1/$pix_per_bp,
        'y'         => $Composite->y() - 1,
        'width'     => $Composite->width() + 2/$pix_per_bp,
        'height'    => $h + 2,
        'colour'    => 'highlight1',
        'absolutey' => 1,
      }));
    }
    #add more detailed links for non chained alignments
    if (scalar(@F) == 1) {
      my $chr_2 = $F[0][1]->hseqname;
      my $s_2   = $F[0][1]->hstart;
      my $e_2   = $F[0][1]->hend;
      my $CONTIGVIEW_TEXT_LINK =  $compara ? 'Jump to ContigView' : 'Centre on this match' ;
      my $END   = $F[0][1]->end;
      my $START  =$F[0][0];
      ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
      my( $rs, $re ) = $self->slice2sr( $START, $END );
      my $jump_type = $species_2;
      my $short_self    = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self_species };
      my $short_other   = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $other_species };
      my $HREF_TEMPLATE = "/$short_self/dotterview?c=$chr:%d;s1=$other_species;c1=%s:%d";
      my $COMPARA_HTML_EXTRA = '';
#      my $MCV_TEMPLATE  = "/$short_self/multicontigview?c=%s:%d;w=%d;s1=$short_other;c1=%s:%d;w1=%d$COMPARA_HTML_EXTRA";
      $zmenu->{'method'} = $self->my_config('type');
      my $href = sprintf $HREF_TEMPLATE, ($rs+$re)/2, $chr_2, ($s_2 + $e_2)/2;
      my $METHOD         = $self->my_config('method' );
      my $link = 0;
      my $TAG_PREFIX;
      if( $compara) {
        $link = $self->my_config('join');
        $TAG_PREFIX  = uc( $compara eq 'primary' ?
          join ( '_', $METHOD, $self_species, $other_species ) :
          join ( '_', $METHOD, $other_species, $self_species ) );
        my $C=1;
        foreach my $T ( @{$self->{'config'}{'other_slices'}||[]} ) {
          if( $T->{'species'} ne $self_species && $T->{'species'} ne $other_species ) {
            $C++;
            $COMPARA_HTML_EXTRA.=";s$C=".$self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $T->{'species'} };
          }
        }
#        $MULTICONTIGVIEW_TEXT_LINK = 'Centre on this match';
      }
    }
    $Composite->href($self->_url($zmenu));
    $self->push( $Composite );
  }
## No features show "empty track line" if option set....
  $self->errorTrack( "No ". $self->my_config('name')." features in this region" ) unless( $C || $self->get_parameter( 'opt_empty_tracks')==0 );
  $self->timer_push( 'Features drawn' );
}

sub render_compact {
  my $self = shift;
  my $WIDTH          = 1e5;
  my $container      = $self->{'container'};
  my $strand         = $self->strand();
  my $strand_flag    = $self->my_config('strand');
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand !=  1;

  my $caption        = $self->my_config('caption');
  my $depth          = $self->my_config('depth');
  $self->_init_bump( undef, $depth );  ## initialize bumping!!
  my %highlights; @highlights{$self->highlights()} = ();

  my $length         = $container->length;
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = $pix_per_bp > 0.2 ;
  my $feature_key    = lc( $self->my_config('type') );
  warn ".... $feature_key ....";
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key,'join'  ) || 'gold'; 
  my $join_z         = $self->my_colour($feature_key,'join_z') || 100;
  my %id             = ();
  my $small_contig   = 0;
  my $h              = $self->get_parameter( 'opt_halfheight') ? 4 : 8;
  my $chr            = $self->{'container'}->seq_region_name;
  my $other_species  = $self->my_config('species' );
  my $species_2      = $self->my_config('species_hr');
  my $self_species   = $container->{web_species};
  my $compara        = $self->get_parameter('compara');
  my $link = 0;
  my $TAG_PREFIX;
  my $METHOD         = $self->my_config('method' );

  my $short_other    = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $other_species };
  my $short_self     = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self_species };

#  warn "compact method is $METHOD";

  my $COMPARA_HTML_EXTRA = '';
#  my $MULTICONTIGVIEW_TEXT_LINK = 'MultiContigView';
  if( $compara ) {
    $link = $self->my_config('join');
    $TAG_PREFIX  = uc( $compara eq 'primary' ?
                       join ( '_', $METHOD, $self_species, $other_species ) :
                       join ( '_', $METHOD, $other_species, $self_species ) );
    my $C=1;
    foreach my $T ( @{$self->{'config'}{'other_slices'}||[]} ) {
      if( $T->{'species'} ne $self_species && $T->{'species'} ne $other_species ) {
        $C++;
        $COMPARA_HTML_EXTRA.=";s$C=".$self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $T->{'species'} };
      }
    }
#    $MULTICONTIGVIEW_TEXT_LINK = 'Centre on this match';
  }

  my $C = 0;
  my $domain = $self->my_config('linkto' );
  my $HREF_TEMPLATE = "/$short_self/dotterview?c=$chr:%d;s1=$other_species;c1=%s:%d";
  my $X = -1e8;
  my $CONTIGVIEW_TEXT_LINK = $compara ? 'Jump to ContigView' : 'Centre on this match' ;
#  my $MCV_TEMPLATE  = "/$short_self/multicontigview?c=%s:%d;w=%d;s1=$short_other;c1=%s:%d;w1=%d$COMPARA_HTML_EXTRA";

#  warn "!>>>>> $other_species $METHOD in compact init<<<<<";
  my @T = sort { $a->[0] <=> $b->[0] }
    map { [$_->start, $_ ] }
    grep { !( ($strand_flag eq 'b' && $strand != $_->hstrand) ||
              ($_->start > $length) ||
              ($_->end < 1)
         ) } @{$self->features()||[]};

  foreach (@T) {
    my($START,$f) = @$_;
    my $END     = $f->end;
    ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
    my( $rs, $re ) = $self->slice2sr( $START, $END );
    $START      = 1 if $START < 1;
    $END        = $length if $END > $length;
    next if int( $END * $pix_per_bp ) == int( $X * $pix_per_bp );
    $X = $START;
    $C++;
    my @X = (
      [ $chr, int(($rs+$re)/2) ],
      [ $f->hseqname, int(($f->hstart + $f->hend)/2) ],
      int($WIDTH/2),
      "@{[$f->hseqname]}:@{[$f->hstart]}-@{[$f->hend]}", 
      "$chr:$rs-$re"
    );
    my $TO_PUSH;
    my $chr_2 = $f->hseqname; 
    my $s_2   = $f->hstart;
    my $e_2   = $f->hend;
    my $href  = '';
    #z menu links depend on whether jumping within or between species;
    my $jump_type = $species_2;

    my $orient = ($f->hstrand * $f->strand > 0) ? 'Forward' : 'Reverse';
    my $zmenu = {
      'type'     => 'Location',
      'action'   => 'ComparaGenomicAlignment',
      'r'        => "$chr:$rs-$re",
      'r1'       => "$chr_2:$s_2-$e_2",
      's1'       => $other_species,
      'method'   => $self->my_config('type'),
      'orient'   => $orient,
    };
    $href = sprintf $HREF_TEMPLATE, ($rs+$re)/2, $chr_2, ($s_2 + $e_2)/2;
    if($DRAW_CIGAR) {
      $TO_PUSH = $self->Composite({
        'href'  => $self->_url($zmenu),
        'x'     => $START-1,
        'width' => 0,
        'y'     => 0
      });
      $self->draw_cigar_feature($TO_PUSH, $f, $h, $feature_colour, 'black', $pix_per_bp, 1 );
      $TO_PUSH->bordercolour($feature_colour);
    } else {
      $TO_PUSH = $self->Rect({
        'x'          => $START-1,
        'y'          => 0,
        'width'      => $END-$START+1,
        'height'     => $h,
        'colour'     => $feature_colour,
        'absolutey'  => 1,
        '_feature'   => $f, 
        'href'  => $self->_url($zmenu),
      });
    }
    if( ($compara eq 'primary' || $compara eq 'secondary') && $link ) {
      my( $start, $end, $start2,$end2) = ( $f->hstart, $f->hend, $f->start, $f->end );
      my( $start2, $end2 ) = $self->slice2sr( $start2, $end2 );
      my $Z = $strand == -1 ? 1 : 0;
      if( $strand != -1 ) {
        my $TAG = $self->{'config'}{'slice_id'}."$TAG_PREFIX.$start.$end:$start2.$end2.$strand";
        $self->join_tag( $TO_PUSH, $TAG, 0, $Z, $join_col, 'fill', $join_z );
        $self->join_tag( $TO_PUSH, $TAG, 1, $Z, $join_col, 'fill', $join_z );
      } else {
        my $TAG = ($self->{'config'}{'slice_id'}+1)."$TAG_PREFIX.$start2.$end2:$start.$end.".(-$strand);
        $self->join_tag( $TO_PUSH, $TAG, 1, $Z, $join_col, 'fill', $join_z );
        $self->join_tag( $TO_PUSH, $TAG, 0, $Z, $join_col, 'fill', $join_z );
      }
    }
    $self->push( $TO_PUSH );
  }
## No features show "empty track line" if option set....
  $self->errorTrack( "No ". $self->my_config('name')." features in this region" ) unless( $C || $self->get_parameter( 'opt_empty_tracks')==0 );
}

1;

sub features {
  my $self = shift;
  return $self->{'container'}->get_all_compara_DnaAlignFeatures(
    $self->my_config( 'species_hr' ),
    $self->my_config( 'assembly'   ),
    $self->my_config( 'type'             ),
    $self->dbadaptor( "multi", $self->my_config('db') )
  );
}

