package Bio::EnsEMBL::GlyphSet::restrict;
use strict;
use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless $self->species_defs->ENSEMBL_EMBOSS_PATH;
  return unless my $strand = $self->strand eq -1;

  my $vc   = $self->{'container'};
  my $config = $self->{'config'};
  my $length = $vc->length;
 
  my $limit = $config->get('restrict','threshold') || 5;
  if($length > $limit * 1010) {
    $self->errorTrack('Restriction enzymes not displayed for more than '.$limit.'Kb');
    return;
  }
  my $PADDING = 90;
  my $col  = undef;
  my $white  = 'white';
  my $black  = 'black';
  my $sequence = $vc->subseq(-$PADDING+1,$length+$PADDING-1);
  my $cut_colour = 'red';
  my $blunt_colour = 'palegreen';
  my $sticky_colour = 'lightskyblue2';
  my $text_colour = 'black';
  my $length = $vc->length;
  my $filename = $self->species_defs->ENSEMBL_TMP_DIR."/".&Digest::MD5::md5_hex(rand()).".restrict";
  my @bitmap; 
  my $pix_per_bp = $config->transform->{'scalex'};
  my $bitmap_length = int ($length * $pix_per_bp );
  my($FONT_I,$FONTSIZE_I) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width(0,'X','','font'=>$FONT_I,'ptsize' => $FONTSIZE_I );
  my $tw_i = $res[3];
  my $th_i = $res[3];
  my($FONT_O,$FONTSIZE_O) = $self->get_font_details( 'outertext' );
  my @res = $self->get_text_width(0,'X','','font'=>$FONT_O,'ptsize' => $FONTSIZE_O );
  my $tw_o = $res[3];
  my $th_o = $res[3];

## CREATE THE emboss in file...
  open O, ">$filename.in";
  print O $sequence;
  close O;
## CALL emboss "restrict"   
  my $command = $self->species_defs->ENSEMBL_EMBOSS_PATH."/bin/restrict -enzymes all -sitelen 4 -seq $filename.in -outfile $filename.out";
  `$command`; 
## CLEAN UP INPUT FILE...
  unlink "$filename.in";

## OPEN UP OUTPUT FILE...
  open I, "$filename.out";
  my @features;
  my @glyphs;
  my %map = qw( S [GC] W [AT] M [AC] K [GT] Y [CT] R [AG] N . V [ACG] H [ACT] D [AGT] B [CGT]);
  while(<I>) {
    next unless ( my( $st, $en, $name, $seq, $s_3p, $s_5p, $s_3pr, $s_5pr ) =
     /^\s*(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s*([.\d]+)\s*([.\d]+)\s*([.\d]+)\s*([.\d]+)/ );
    ( my $regexp = "^$seq".'$' ) =~s/([SWMKYRNVHDB])/$map{$1}/eg;
    
    my $STR = $st > $en ? substr($sequence, $en-1, $st-$en+1) : substr($sequence, $st-1, $en-$st+1);
    if( $st > $en ) {
      ($st,$en,$s_3p,$s_5p,$s_5pr,$s_3pr) = ($en,$st,$s_5p,$s_3p,$s_3pr,$s_5pr);
    }
  #  if( $STR =~ /$regexp/ ) {
  #    warn "-> FLIP NOT REQUIRED";
  #  } else {
  #    warn "-> FLIP CALLED....";
  #    $en = 2 * $st - $en;
  #    if($s_3p ne '.') {
  #      ($s_3p,$s_5p) = (2*$st-$s_5p-1,2*$st-$s_3p-1);
  #    } 
  #    if($s_3pr ne '.' ) {
  #      ($s_3pr,$s_5pr) = (2*$st-$s_5pr-1,2*$st-$s_3pr-1);
  #    }
  #    ($st,$en) = ($en,$st);
  #  }
    $s_3pr = -10000 if $s_3pr eq '.'; # if not mapped...
    $s_5pr = -10000 if $s_5pr eq '.';
    $s_3p  = -10000 if $s_3p eq '.';
    $s_5p  = -10000 if $s_5p eq '.';
    $st    -= $PADDING; # adjust off previous padding!!
    $en    -= $PADDING;
    $s_3p  -= $PADDING;
    $s_5p  -= $PADDING;
    $s_3pr -= $PADDING;
    $s_5pr -= $PADDING;
    next if $s_3pr < 1 && $s_5pr < 1 && $s_3p < 1 && $s_5p < 1 && $st < 1 && $en < 1 ; # skip if falls off LH end
    next if ( $s_3pr < -1000 || $s_3pr > $length ) &&
            ( $s_3pr < -1000 || $s_3pr > $length ) &&
            ( $s_3pr < -1000 || $s_3pr > $length ) &&
            ( $s_3pr < -1000 || $s_3pr > $length ) &&
            $st > $length && $en > $length ;                                           # skip if falls off RH end
    push @features, {
      'start' => $st,
      'end'   => $en,
      'name'  => $name,
      'seq'   => $seq,
      '3p'  => $s_3p < -10000 ? '' : $s_3p,
      '5p'  => $s_5p < -10000 ? '' : $s_5p,
      '3pr'   => $s_3pr < -10000 ? '' : $s_3pr,
      '5pr'   => $s_5pr < -10000 ? '' : $s_5pr,
    };
  }
  close I;
  unlink "$filename.out";

## Now we do the rendering of the features...

  my %points = ( '5p' => [ .5, 1 ], '3p' => [ 0, 0 ], '5pr' => [ .5, 1 ], '3pr' => [ 0, 0 ] );

  my $seq = $vc->seq();
  my $H=0;
  foreach my $f ( @features ) {
    my $colour = ( $f->{'5p'} eq $f->{'3p'} && $f->{'3pr'} eq $f->{'5pr'} ) ? $blunt_colour : $sticky_colour;
    my $start = $f->{'start'} < 1 ? 1 : $f->{'start'};
    my $end   = $f->{'end'} > $length ? $length : $f->{'end'};
    my $Composite = $self->Composite({
      'zmenu'  => { 'caption' => $f->{'name'}, "Seq: $f->{'seq'}" => '' },
      'x' => $start > $length ? $length : $start,
      'y' => 0
    });
    unless($start > $length || $end < 1 ) {
      $Composite->push( $self->Rect({
        'x'    => $start -1 ,
        'y'    => 0,
        'width'  => $end - $start +1 ,
        'height' => $th_i + 2,
        'colour' => $colour,
        'absolutey' => 1,
      }));
      if( $pix_per_bp > $tw_i ) {
        my $O = -1;
        foreach( split //, substr($seq, $start-1, $end-$start+1 ) ) {
          my @res = $self->get_text_width( $pix_per_bp, $_,'', 'font'=>$FONT_I, 'ptsize' => $FONTSIZE_I );
          my $tmp_width = $res[2]/$pix_per_bp;
          $Composite->push( $self->Text({
            'x'      => $start+0.5+$O- $tmp_width/2,
            'y'      => 0,
            'width'    => $tmp_width,
            'textwidth' => $res[2],
            'height'   => $th_i,
            'font'     => $FONT_I,
            'ptsize'  => $FONTSIZE_I,
            'colour'   => $text_colour,
            'text'     => $_,
            'absolutey'  => 1,
          }));
          $O++;
        }
      }
    }
    if( $pix_per_bp > .3 ) {
      foreach my $tag ( keys %points ) {
        my $X = $f->{ $tag };
        next if $X eq '';
        my $h1 = $points{ $tag }[0] * ($th_i+2);
        my $h2 = $points{ $tag }[1] * ($th_i+2);
        if( $X < $f->{'start'} ) { ## LH tag
          unless($f->{'start'}<1) {
            if($X<1) { ## DO NOT DRAW DOWN TAG
              $X = 0;
            } else {
              $Composite->push( $self->Rect({
                'x'    => $X  , 'y'    => $h1, 'width'  => 0,
                'height' => 5, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
            my $E = $f->{'start'} >= $length ? $length : $f->{'start'};
            if($E-$X-1>0) {
              $Composite->push( $self->Rect({
                'x'    => $X  , 'y'    => $h2, 'width'  => $E - $X - 1,
                'height' => 0, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
          }
        } elsif( $X >= $f->{'end'} ) { ## RH tag
          unless($f->{'end'}>$length) {
            if($X>=$length) { ## DO NOT DRAW DOWN TAG
              $X = $length;
            } else {
              $Composite->push( $self->Rect({
                'x'    => $X  , 'y'    => $h1, 'width'  => 0,
                'height' => 5, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
            my $S = $f->{'end'} < 1 ? 0 : $f->{'end'};
            if( $X-$S > 0 ) {
              $Composite->push( $self->Rect({
               'x'    => $S , 'y'    => $h2, 'width'  => $X - $S ,
               'height' => 0, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
          }
        } else { ## Within site...
          unless($X<1 || $X>$length) {
            $Composite->push( $self->Rect({
              'x'    => $X  , 'y'    => $h1, 'width'  => 0,
              'height' => 5, 'colour' => $cut_colour, 'absolutey' => 1,
            }));
          }
        }
      }
    }
    next unless @{$Composite->{'composite'}||[]};
    
    my(@res) = $self->get_text_width(0,$f->{'name'},'','font'=>$FONT_O,'ptsize' => $FONTSIZE_O );

    $Composite->push( $self->Text({
      'x'         => $Composite->x,
      'y'         => $th_i+4 ,
      'width'     => $pix_per_bp * $res[2],
      'height'    => $th_o,
      'halign'    => 'left',
      'font'      => $FONT_O,
      'ptsize'    => $FONTSIZE_O,
      'colour'    => $text_colour,
      'text'      => $f->{'name'},
      'absolutey' => 1,
    }));
    $H = $th_i+4;

    my $bump_start = int($Composite->x * $pix_per_bp);
    my $bump_end   = $bump_start + int( ($Composite->width) * $pix_per_bp);
       $bump_start--; 
       $bump_start = 0 if $bump_start < 0;
       $bump_end   = $bitmap_length if $bump_end > $bitmap_length;
    my $row = & Sanger::Graphics::Bump::bump_row(
       $bump_start,  $bump_end,  $bitmap_length,  \@bitmap
    );
    push @glyphs, [ $Composite, $row ];
  }
  foreach (@glyphs) { $_->[0]->y( $_->[0]->y - (18+$H) * $_->[1] * $strand ) ; }
  $self->push( map { $_->[0] } @glyphs );
}

1;
