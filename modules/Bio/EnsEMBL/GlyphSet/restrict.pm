package Bio::EnsEMBL::GlyphSet::restrict;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Composite;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  my $label = new Sanger::Graphics::Glyph::Text({
    'text'    => "Restr.Enzymes",
    'font'    => 'Small',
    'absolutey' => 1,
  });
  $self->label($label);
}

sub _init {
  my ($self) = @_;
  return unless EnsWeb::species_defs->ENSEMBL_EMBOSS_PATH;
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
  my $cmap   = $config->colourmap();
  my $white  = 'white';
  my $black  = 'black';
  my $sequence = $vc->subseq(-$PADDING+1,$length+$PADDING-1);
  my $cut_colour = 'red';
  my $blunt_colour = 'palegreen';
  my $sticky_colour = 'lightskyblue2';
  my $text_colour = 'black';
  my $length = $vc->length;
  my $filename = $EnsWeb::species_defs->ENSEMBL_TMP_DIR."/".&Digest::MD5::md5_hex(rand()).".restrict";
  my @bitmap; 
  my $pix_per_bp = $config->transform->{'scalex'};
  my $bitmap_length = int ($length * $pix_per_bp );
  my ($w,$th) = $config->texthelper()->px2bp('Tiny');

## CREATE THE emboss in file...
  open O, ">$filename.in";
  print O $sequence;
  close O;
## CALL emboss "restrict"   
  my $command = EnsWeb::species_defs->ENSEMBL_EMBOSS_PATH."/bin/restrict -enzymes all -sitelen 4 -seq $filename.in -outfile $filename.out";
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
  # unlink "$filename.out";

## Now we do the rendering of the features...

  my %points = ( '5p' => [ 5, 10 ], '3p' => [ 0, 0 ], '5pr' => [ 5, 10 ], '3pr' => [ 0, 0 ] );

  my $seq = $vc->seq();
  my $H=0;
  foreach my $f ( @features ) {
    my $colour = ( $f->{'5p'} eq $f->{'3p'} && $f->{'3pr'} eq $f->{'5pr'} ) ? $blunt_colour : $sticky_colour;
    my $start = $f->{'start'} < 1 ? 1 : $f->{'start'};
    my $end   = $f->{'end'} > $length ? $length : $f->{'end'};
    my $Composite = new Sanger::Graphics::Glyph::Composite({
      'zmenu'  => { 'caption' => $f->{'name'}, "Seq: $f->{'seq'}" => '' },
      'x' => $start > $length ? $length : $start,
      'y' => 0
    });
    unless($start > $length || $end < 1 ) {
      $Composite->push( new Sanger::Graphics::Glyph::Rect({
        'x'    => $start -1 ,
        'y'    => 0,
        'width'  => $end - $start +1 ,
        'height' => 10,
        'colour' => $colour,
        'absolutey' => 1,
      }));
      if( $pix_per_bp > $w * 1.1 ) {
        my $O = -1/2-$w/2;
        foreach( split //, substr($seq, $start-1, $end-$start+1 ) ) {
          $Composite->push( new Sanger::Graphics::Glyph::Text({
            'x'      => $start + $O,
            'y'      => 1,
            'width'    => $w,
            'height'   => $th,
            'font'     => 'Tiny',
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
        my $h1 = $points{ $tag }[0];
        my $h2 = $points{ $tag }[1];
        if( $X < $f->{'start'} ) { ## LH tag
          unless($f->{'start'}<1) {
            if($X<1) { ## DO NOT DRAW DOWN TAG
              $X = 0;
            } else {
              $Composite->push( new Sanger::Graphics::Glyph::Rect({
                'x'    => $X  , 'y'    => $h1, 'width'  => 0,
                'height' => 5, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
            my $E = $f->{'start'} >= $length ? $length : $f->{'start'};
            if($E-$X-1>0) {
              $Composite->push( new Sanger::Graphics::Glyph::Rect({
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
              $Composite->push( new Sanger::Graphics::Glyph::Rect({
                'x'    => $X  , 'y'    => $h1, 'width'  => 0,
                'height' => 5, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
            my $S = $f->{'end'} < 1 ? 0 : $f->{'end'};
            if( $X-$S > 0 ) {
              $Composite->push( new Sanger::Graphics::Glyph::Rect({
               'x'    => $S , 'y'    => $h2, 'width'  => $X - $S ,
               'height' => 0, 'colour' => $cut_colour, 'absolutey' => 1,
              }));
            }
          }
        } else { ## Within site...
          unless($X<1 || $X>$length) {
            $Composite->push( new Sanger::Graphics::Glyph::Rect({
              'x'    => $X  , 'y'    => $h1, 'width'  => 0,
              'height' => 5, 'colour' => $cut_colour, 'absolutey' => 1,
            }));
          }
        }
      }
    }
    next unless @{$Composite->{'composite'}||[]};
    if( $Composite->width * 2 > 1.2 * $w / $pix_per_bp * length( $f->{'name'} ) ) {
      $Composite->push( new Sanger::Graphics::Glyph::Text({
        'x'         => $Composite->x,
        'y'         => 12 ,
        'width'     => $pix_per_bp * $w * length( $f->{'name'} ),
        'height'    => $th,
        'font'      => 'Tiny',
        'colour'    => $text_colour,
        'text'      => $f->{'name'},
        'absolutey' => 1,
      }));
      $H = $th+2;
    }
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
  foreach (@glyphs) { $_->[0]->y( $_->[0]->y - (12+$H) * $_->[1] * $strand ) ; }
  $self->push( map { $_->[0] } @glyphs );
}

1;
