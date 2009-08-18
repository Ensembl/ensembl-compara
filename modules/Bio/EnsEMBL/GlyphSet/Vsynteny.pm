package Bio::EnsEMBL::GlyphSet::Vsynteny;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub chr_sort {
  my $self = shift;
  my $large_value = 1e10;
  return 
    map { $_ == ($large_value+1) ? 'Y' : ( $_ == $large_value ? 'X' : $_ ) } 
    sort { $a <=> $b }
    map { $_ eq 'Y' ? ($large_value+1) : ( $_ eq 'X' ? $large_value : $_ ) } 
    @_;
}

sub _init {
  my ($self) = @_;

  my $Config = $self->{'config'};

  return unless $Config->container_width()>0; # The container has zero width !!EXIT!!
    
## FIRSTLY LETS SORT OUT THE COLOURS!!
  my $cmap   = $Config->colourmap();
  my $white  = 'white';
  my $black  = 'black';
  my $grey   = 'grey60';
  my $red    = 'red';
  my $blue   = 'blue';
  my $brown  = 'rust';

    my @BORDERS = map { $cmap->add_hex($_) } qw(00cc00 ff66FF 3333ff 009999 ff9900 993399 cccc00);
    my @COLOURS = map { $cmap->add_hex($_) } qw(99ff99 ffccff 9999ff 99ffff ffcc99 cc99ff ffff99);
    @BORDERS = (@BORDERS,@BORDERS,@BORDERS);
    @COLOURS = (@COLOURS,@COLOURS,@COLOURS);
    my $bg     = $Config->get_parameter( 'bgcolor');

## LETS GRAB THE DATA FROM THE CONTAINER
    my $chr         = $self->{'container'}->{'chr'} || 1;
    my $kba         = $self->{'container'}->{'ka_main'};
    my $kba2        = $self->{'container'}->{'ka_secondary'};
    my $sa         = $self->{'container'}->{'sa_main'};
    my $sa2        = $self->{'container'}->{'sa_secondary'};
    my $synteny_data= $self->{'container'}->{'synteny'};

    my $OTHER       = $self->{'container'}->{'other_species'};
    my $OTHER_T     = $OTHER; $OTHER_T =~s/_/ /g;
    my $SPECIES_T   = $self->{container}{web_species}; $SPECIES_T =~s/_/ /g;
    my $OTHER_SHORT = $self->species_defs->get_config($OTHER,'SPECIES_COMMON_NAME');
    my $SPECIES_SHORT = $self->species_defs->SPECIES_COMMON_NAME;
    $SPECIES_T =~ s/_/ /g;
## This is the list of chromosomes we will be drawing     

    my %other_chrs = map { ($_ , 1) } @{ $self->species_defs->get_config($OTHER,'ENSEMBL_CHROMOSOMES') };
    
## LETS GRAB THE CHROMOSOME BANDS FOR THE CENTRAL CHROMOSOME

    my $chr_length  = $sa->fetch_by_region( 'toplevel', $chr )->length; 
    my $bands       = $kba->fetch_all_by_chr_name( $chr ) || [];

## NOW LETS GRAB THE IMAGE PARAMETERS
    my $im_width            = $Config->image_width();
    my $length              = $Config->get_parameter('image_height'); 
    my $top_margin          = $Config->get_parameter('top_margin');
    my $main_width          = $Config->get_parameter('main_width');
    my $padding             = $Config->get_parameter('padding');
    my $outer_padding       = $Config->get_parameter('outer_padding');
    my $inner_padding       = $Config->get_parameter('inner_padding');
    my $secondary_width     = $Config->get_parameter('secondary_width');
    my $spacing             = $Config->get_parameter('spacing');
## LET us derive the next set of values....        
    my $h_offset            = $im_width - $top_margin * 2 - $length;
#    my $bpperpx             = $Config->container_width()/$length;
#    my ($w,$h)              = $Config->texthelper->Vpx2bp('Tiny');
    my $v_offset            = $Config->container_width() ; # * ( $top_margin + $length ) /$length; # bottom align each chromosome!

## Finally some parameters for the drawing code...
    my $done_1_acen         = 0;        # flag for tracking place in chromsome
    # max width of band label is 6 characters

## Synteny drawing stage 1....
##   Part 2: Draw the central karyotype

##   Part 1: Draw a box behind the karyotype

    my @chromosomes = ();
    my $highlights_secondary = {};
    my %colour;
    my %side;
    my %border;
    my $side =1;
    my $COL;
    my $SIDE;
    my $BORD;
#    my $this_chr = $synteny_data->[0]->{'chr_name'};
    my $highlights_main      = { $chr => [] };

    my $CANSEE_OTHER = $Config->{'other_species_installed'};

    foreach my $box ( @$synteny_data ) {
      my ($main_dfr, $other_dfr);
      foreach my $dfr (@{$box->children}) {
        if ($dfr->dnafrag->genome_db->name eq $OTHER_T) {
          $other_dfr = $dfr;
        } else {
          $main_dfr = $dfr;
        }
      }
#        my $other_chr = $box->{'hit_chr_name'};
        my $other_chr = $other_dfr->dnafrag->name;
        if(!$other_chrs{$other_chr}) { ## We have a hit on another chromosome 
            $COL = $grey;
            $BORD = $black;
            $SIDE = 0;
        } elsif( exists $highlights_secondary->{$other_chr} ) { ## We have a hit which is on a chr... which we've already positioned
            $COL  = $colour{$other_chr};
            $SIDE = $side{$other_chr};
            $BORD = $border{$other_chr};
        } else { ## We have a hit which is on a chr... which we have already to position
            $highlights_secondary->{$other_chr}=[];
            $COL = shift @COLOURS;
            $BORD = shift @BORDERS;
            push @chromosomes, $other_chr;
            $side *=-1;
            $SIDE = $side;
            $side{$other_chr} = $side;
            $colour{$other_chr} = $COL;
            $border{$other_chr} = $BORD;
        }
        my $url = $self->_url({
	    'action'  => 'Overview',
	    'species' => $self->{container}{web_species},
	    't'       => undef,
	    'r'       => "$chr:".$main_dfr->dnafrag_start.'-'.$main_dfr->dnafrag_end,
	    'r1'      => "$other_chr:".$other_dfr->dnafrag_start.'-'.$other_dfr->dnafrag_end,
	    'sp1'     => $OTHER,
	    'ori'     => '',
	});

#	    '03:Centre gene list' => qq(/@{[$self->{container}{web_species}]}/syntenyview?otherspecies=$OTHER;chr=$chr;loc=).int(($main_dfr->dnafrag_end+$main_dfr->dnafrag_start)/2)

        push @{$highlights_main->{$chr}}, {
            'id' => $box->dbID,
            'start'=> $main_dfr->dnafrag_start,
            'end' => $main_dfr->dnafrag_end,
            'col' => $COL,
            'border' => $BORD,
            'side' => $SIDE,
            'href' => $url,
        };
        if($SIDE) {
            my $marked =
                ($main_dfr->dnafrag_start <= $self->{'container'}->{'line'} && $self->{'container'}->{'line'} <= $main_dfr->dnafrag_end) ? $SIDE : 0;
	    my $ori = ($main_dfr->dnafrag_strand * $other_dfr->dnafrag_strand == 1) ? 'forward' : 'reverse';
	    my $url = $self->_url({
		'action'  => 'Overview',
		'species' => $OTHER,
		't'       => undef,
		'r1'      => "$chr:".$main_dfr->dnafrag_start.'-'.$main_dfr->dnafrag_end,
		'r'       => "$other_chr:".$other_dfr->dnafrag_start.'-'.$other_dfr->dnafrag_end,
		'ori'     => $ori,
		'sp1'      => $self->{container}{web_species},
	    });
            push @{$highlights_secondary->{$other_chr}}, {
                'rel_ori' => $main_dfr->dnafrag_strand * $other_dfr->dnafrag_strand,
                'id' => $box->dbID,
                'start'=> $other_dfr->dnafrag_start,
                'end' => $other_dfr->dnafrag_end,
                'col' => $COL,
                'border' => $BORD,
                'side' => 0,
                'href' => $url,
                'marked' => $marked,
            };
        }
    }
    my %main_coords = $self->draw_chromosome( 
        'bands'         => $bands,
        'h_offset'      => $outer_padding + $inner_padding + $secondary_width,
        'v_offset'      => $h_offset,
        'length'        => $length,
        'chr_length'    => $chr_length,
        'chr'           => $chr,
        'width'         => $main_width,
        'white'         => $white,
        'black'         => $black,
        'grey'          => $grey,
        'red'           => $red,
        'bg'            => $bg,
        'highlights'    => $highlights_main->{$chr},
        'font'          => 'Tiny',
        'ruler'         => ( $chr_length> 10e7 ? 2e7 : 1e7 ),
        'line'          => $self->{'container'}->{'line'}
    );

    my %secondary_coords;
    my $num_chr     = @chromosomes;
    my $flag = 0;
    my $N=0;
    my $FLAG = $num_chr%2 == 0; ## FLAG MEANS THAT EVEN START AT 0...
    return if $num_chr==0;
    my $secondary_length = int( 2 * ( $length + $spacing ) / ($num_chr+1-$FLAG) - $spacing );
    foreach my $chr2 ( @chromosomes ) {
        my $chr_length_2  = $sa2->fetch_by_region( 'toplevel', $chr2 )->length() || 0;
        my $bands_2       = $kba2->fetch_all_by_chr_name( $chr2 );
        my ($h_offset2, $v_offset2) = $flag==0 ?
            ( $h_offset + $N/2 * ( $secondary_length + $spacing ),
              $outer_padding) : # LHS
            ( $h_offset + ($N-$FLAG)/2 * ( $secondary_length + $spacing ),
              2 * $inner_padding + $secondary_width + $main_width + $outer_padding) ; # RHS
        my $mb_p_p = ($chr_length_2 / $secondary_length / 1e6);
        my $ruler = $mb_p_p > 0.75 ? 5e7 : ($mb_p_p > 0.15 ? 2e7 : 1e7);
        my %t = $self->draw_chromosome( 
            'bands'         => $bands_2,
            'h_offset'      => $v_offset2,
            'v_offset'      => $h_offset2,
            'length'        => $secondary_length,
            'chr_length'    => $chr_length_2,
            'width'         => $secondary_width,
            'white'         => $white,
            'black'         => $black,
            'grey'          => $grey,
            'red'           => $red,
            'bg'            => $bg,
            'chr_name'      => "Chr $chr2",
            'font'          => 'Tiny',
            'ruler'         => $ruler,
            'ruler_offset'  => $flag == 0 ? 'l' : 'r',
            'highlights'    => $highlights_secondary->{$chr2}
        );      
        while(my($k,$v)=each(%t)) {
            $secondary_coords{$k}=$v;
        }
        $N++;
        $flag = 1-$flag;
    }        
    foreach(keys %secondary_coords) {
        my($Y1,$Y2);
        my $X1 = ($secondary_coords{$_}->{'top'}+$secondary_coords{$_}->{'bottom'})/2;
        my $X2 = ($main_coords{$_}->{'top'}+$main_coords{$_}->{'bottom'})/2;
        if($secondary_coords{$_}->{'left'} > $main_coords{$_}->{'left'}) {
            ($X1,$X2)=($X2,$X1);
            $Y1 = $main_coords{$_}->{'right'};
            $Y2 = $secondary_coords{$_}->{'left'};
        } else {
            $Y1 = $secondary_coords{$_}->{'right'};
            $Y2 = $main_coords{$_}->{'left'};
        }
        my $COL = $secondary_coords{$_}->{'rel_ori'} == 1 ? $black : $brown;
        $self->push($self->Line({
            'x'       => $X1,
            'y'       => $Y1,
            'width'   => 0,
            'height'  => ($Y2-$Y1)/10,
            'colour'           =>  $COL,
            'absolutey'        => 1, 'absolutex'        => 1,'absolutewidth'=>1,
        }));
        $self->push($self->Line({
            'x'       => $X1,
            'y'       => $Y1 + ($Y2-$Y1)/10,
            'width'   => $X2-$X1,
            'height'  => 4*($Y2-$Y1)/5,
            'colour'           => $COL,
            'absolutey'        => 1, 'absolutex'        => 1,'absolutewidth'=>1,
        }));
        $self->push($self->Line({
            'x'       => $X2,
            'y'       => $Y2 - ($Y2-$Y1)/10,
            'width'   => 0,
            'height'  => ($Y2-$Y1)/10,
            'colour'           =>  $COL,
            'absolutey'        => 1, 'absolutex'        => 1,'absolutewidth'=>1,
        }));
    }
    my $w = $self->{'config'}->texthelper->width('Tiny');
    my $h = $self->{'config'}->texthelper->height('Tiny');
    $self->unshift($self->Text({
            'x'          => $im_width - $h - 2 - $top_margin,
            'y'          => $outer_padding + $secondary_width/2 - $w * length($OTHER_T)/2,
            'font'       => 'Tiny',
            'colour'     => $black,
            'text'       => $OTHER_T,
            'absolutey'  => 1, 'absolutex' => 1,'absolutewidth'=>1,
    }));
    $self->unshift($self->Text({
            'x'          => $im_width - $h - 2 - $top_margin ,
            'y'          => $outer_padding + $inner_padding*2 + $main_width + 3*$secondary_width/2 - $w * length($OTHER_T)/2,
            'font'       => 'Tiny',
            'colour'     => $black,
            'text'       => $OTHER_T,
            'absolutey'  => 1, 'absolutex' => 1,'absolutewidth'=>1,
    }));
    $self->unshift($self->Rect({
            'x'          => 0,
            'y'          => 0,
            'width'      => $im_width,
            'height'     => ($outer_padding + $secondary_width + $inner_padding ) * 2 + $main_width,
            'absolutey'  => 1,
            'absolutex'  => 1,'absolutewidth'=>1,
    }));
}

sub draw_chromosome {
    my $self = shift;
    my %params = @_;
    ## contains hash 'bands', 'h_offset', 'v_offset', 
    ##               'length', 'chr_length', 'width',
    ##               'grey', 'black', 'bg', 'white', 
    ##               'chr_name', 'font' ## will be used for labelling in future
    my $h_offset   = $params{'h_offset'};
    my $v_offset   = $params{'v_offset'};
    my $length     = $params{'length'};
    my $chr_length = $params{'chr_length'};
    my $scale      = $length / $chr_length;
    my $wid        = $params{'width'};
    my $h_wid      = $wid/2;
    my $done_1_acen = 0;
    my $highlights = $params{'highlights'} || [];
    my @bands = sort{$a->start <=> $b->start } @{$params{'bands'}||[]};
    if( @bands ) {
      foreach my $band (@bands ) {
        my $bandname       = $band->name();
        my $vc_band_start  = $band->start() * $scale + $v_offset;
        my $vc_band_end    = $band->end()   * $scale + $v_offset;
        my $stain          = $band->stain();
	
        if ($stain eq "acen"){
	  my $gband;
	  if ($done_1_acen){
	    $self->push($self->Poly
			({
			  'points'       => [ 
					     $vc_band_start, 
					     $h_offset + $h_wid, 
					     $vc_band_end,   
					     $h_offset,
					     $vc_band_end,   
					     $h_offset+$wid,
					    ],
			  'colour'       => $params{'grey'},
			  'absolutey'    => 1,    
			  'absolutex'    => 1,
			  'absolutewidth'=>1,
                }));
            } else {
                $self->push($self->Poly
			    ({
			      'points' => [ 
					   $vc_band_start, 
					   $h_offset, 
					   $vc_band_end,
					   $h_offset + $h_wid,
					   $vc_band_start, 
					   $h_offset + $wid,
					  ],
			      'colour'       => $params{'grey'},
			      'absolutey'    => 1,    
			      'absolutex'    => 1,
			      'absolutewidth'=>1,
                }));
                $done_1_acen = 1;
            }
        } elsif ($stain eq "stalk"){
            $self->push($self->Poly
			({
			  'points' => [
				       $vc_band_start, 
				       $h_offset, 
				       $vc_band_end,   
				       $h_offset + $wid,
				       $vc_band_end,   
				       $h_offset,
				       $vc_band_start, 
				       $h_offset + $wid, 
				      ],
			  'colour'       => $params{'grey'},
			  'absolutey'    => 1,    
			  'absolutex'    => 1,
			  'absolutewidth'=>1,
            }));
            $self->push($self->Rect
			({
			  'x'            => $vc_band_start,
			  'y'            => $h_offset + int($wid/4),
			  'width'        => $vc_band_end - $vc_band_start,
			  'height'       => $h_wid,
			  'colour'       => $params{'grey'},
			  'absolutey'    => 1,    
			  'absolutex'    => 1,
			  'absolutewidth'=>1,
            }));
	  } else {
            $self->unshift($self->Rect
			   ({
			     'x'          => $vc_band_start,
			     'y'          => $h_offset,
			     'width'      => $vc_band_end - $vc_band_start,
			     'height'     => $wid,
			     'colour'     => ( $stain eq 'tip' ? 
					       $params{'grey'} : 
					       $params{'white'} ),
			     'absolutey'  => 1,
			     'absolutex'  => 1,
			     'absolutewidth'=>1,
            }));
            $self->push($self->Line
			({
			  'x'            => $vc_band_start,
			  'y'            => $h_offset,
			  'width'        => $vc_band_end - $vc_band_start,
			  'height'       => 0,
			  'colour'       => $params{'black'},
			  'absolutey'    => 1, 
			  'absolutex'    => 1,
			  'absolutewidth'=>1,
            }));
            $self->push($self->Line
			({
			  'x'            => $vc_band_start,
			  'y'            => $h_offset+$wid,
			  'width'        => $vc_band_end - $vc_band_start,
			  'height'       => 0,
			  'colour'       => $params{'black'},
			  'absolutey'    => 1, 
			  'absolutex'    => 1,
			  'absolutewidth'=>1,
            }));
	  }
      }
    }
    else {
      $self->unshift($self->Rect
		     ({
		       'x'          => $v_offset,
		       'y'          => $h_offset,
		       'width'      => $chr_length * $scale,
		       'height'     => $wid,
		       'colour'     => $params{'white'},
		       'absolutey'  => 1,
		       'absolutex'  => 1,'absolutewidth'=>1,
		      }));
      foreach my $Y ($h_offset, $h_offset+$wid){
	$self->push($self->Line
		    ({
		      'x'                => $v_offset+1,
		      'y'                => $Y,
		      'width'            => $chr_length * $scale -1,
		      'height'           => 0,
		      'colour'           => $params{'black'},
		      'absolutey'        => 1, 
		      'absolutex'        => 1,'absolutewidth'=>1,
		     }));
      }
    } 
    my @lines = $wid < 16 ? ( [8,6],[4,4],[2,2] ) :
               ( $wid < 30 ? ( [8,5],[5,3],[4,1],[3,1],[2,1],[1,1],[1,1],[1,1] ) :
                ( [8,8],[5,3],[4,1],[3,1],[2,1],[1,1],[1,1],[1,1] ) );

    my $divisor = $wid<30 ? 24 : 30;         
## This is the end of the         

    my @ends;
    if ( @bands ){
	@ends = (( $bands[0]->stain() eq 'tip' ? () : 1 ),
	    ( $bands[-1]->stain() eq 'tip' ? () : -1 ));
    } else {
        @ends = (-1,1);
    }
    foreach my $end (@ends){
        foreach my $I ( 0..$#lines ) {
            my ( $bg_x, $black_x ) = @{$lines[$I]};
            my $xx =  ($end==1 ? $v_offset : $v_offset + $length) + $end * $I;
            $self->push($self->Line({
                    'x'         => $xx,
                    'y'         => $h_offset,
                    'width'     => 0,
                    'height'    => $wid * $bg_x/$divisor -1,
                    'colour'    => 'background1',
                    'absolutey' => 1,   'absolutex' => 1,'absolutewidth'=>1,
            }));
            $self->push($self->Line({
                    'x'         => $xx,
                    'y'         => $h_offset + 1 + $wid * (1-$bg_x/$divisor),
                    'width'     => 0,
                    'height'    => $wid * $bg_x/$divisor -1 ,
                    'colour'    => 'background1',
                    'absolutey' => 1,   'absolutex' => 1,'absolutewidth'=>1,
            }));
            $self->push($self->Line({
                    'x'         => $xx,
                    'y'         => $h_offset + $wid * $bg_x/$divisor,
                    'width'     => 0,
                    'height'    => $wid * $black_x/$divisor -1 ,
                    'colour'    => 'black',
                    'absolutey' => 1, 'absolutex' => 1,'absolutewidth'=>1,
            }));
            $self->push($self->Line({
                    'x'         => $xx,
                    'y'         => $h_offset + 1 + $wid * (1-$bg_x/$divisor-$black_x/$divisor),
                    'width'     => 0,
                    'height'    => $wid * $black_x/$divisor -1 ,
                    'colour'    => 'black',
                    'absolutey' => 1, 'absolutex' => 1,'absolutewidth'=>1,
            }));
        }
    }
    my ($w,$h);
    if($params{'font'}) {
        $w = $self->{'config'}->texthelper->width($params{'font'});
        $h = $self->{'config'}->texthelper->height($params{'font'});
    }
    if($params{'ruler'}) {
        my $X = $params{'ruler'};
        my $flag = $params{'ruler_offset'};
        while($X<$chr_length) {
            my $xx = $X * $scale + $v_offset;
            $self->push($self->Line({
                    'x'         => $xx,
                    'y'         => $h_offset + ($params{'ruler_offset'} eq 'r' ? $wid : ($params{'ruler_offset'} eq 'l' ? -3  : 0)),
                    'width'     => 0,
                    'height'    => 3,
                    'colour'    => $params{'black'},
                    'absolutey' => 1, 'absolutex' => 1,'absolutewidth'=>1,
            }));
            if($params{'font'}) {
                my $TEXT = int($X/1000000)."M";
                $self->push($self->Text({
                    'x'          => $xx-$h/2,
                    'y'          => $h_offset + ($params{'ruler_offset'} eq 'r' ? $wid + 5 : ($params{'ruler_offset'} eq 'l' ? -5-length($TEXT)*$w : 5)), 
                    'font'       => $params{'font'},
                    'colour'     => $params{'black'},
                    'text'       => $TEXT,
                    'absolutey'  => 1, 'absolutex' => 1,'absolutewidth'=>1,
                }));
            }
            $X+=$params{'ruler'};
        }
    }
    if($params{'font'} && $params{'chr_name'}) {
        $self->push($self->Text({
            'x'          => $v_offset + $length +3 ,
            'y'          => $h_offset + $h_wid - $w * length($params{'chr_name'})/2,
            'font'       => $params{'font'},
            'colour'     => $params{'black'},
            'text'       => $params{'chr_name'},
            'absolutey'  => 1, 'absolutex' => 1,'absolutewidth'=>1,
        }));
    }
    
    my %coords;
    foreach my $box (@$highlights) {
        my $vc_start  = $box->{'start'} * $scale + $v_offset;
        my $vc_end    = $box->{'end'}   * $scale + $v_offset;
        $coords{$box->{'id'}} = {
            'left'  => $h_offset + $box->{'side'} * ($wid+4),
            'right' => $h_offset + $box->{'side'} * ($wid+4) + $wid,
            'top'   => $vc_start,
            'bottom'=> $vc_end,
            'rel_ori' => $box->{'rel_ori'}
        };
        $self->push($self->Rect({
            'x'          => $vc_start,
            'y'          => $h_offset + $box->{'side'} * ($wid+4),
            'width'      => $vc_end - $vc_start,
            'height'     => $wid,
            'colour'     => $box->{'col'},
            'bordercolour'     => $box->{'border'},
            'absolutey'  => 1,
            'absolutex'  => 1,'absolutewidth'=>1,
            'href' => $box->{'href'},
            'zmenu' => $box->{'zmenu'}
        }));
        if($box->{'marked'}==1 || $box->{'marked'}==-1) {
            $self->push($self->Rect({
                'x'          => $vc_start -2,
                'y'          => $h_offset + ($box->{'marked'}==1 ? $wid+3 : -4 ), 
                'width'      => $vc_end - $vc_start + 4,
                'height'     => 2,
                'bordercolour'     => $params{'red'},
                'absolutey'  => 1,
                'absolutex'  => 1,'absolutewidth'=>1,
            }));
        }
    }
    if($params{'line'}) {
	my $start = $params{'line'}-5e5;
	my $stop = $start+1e6-1;
	my $r = $params{'chr'} . ":$start-$stop";
	my $url = $self->_url({
	    'type'    => 'Location',
	    'action'  => 'View',
	    'r'       =>$r,
	    'species' => $self->{container}{web_species}});
        $self->push($self->Rect({
            'x'          => $v_offset + $params{'line'} * $scale - 1,
            'y'          => $h_offset - 2,
            'width'      => 3,
            'height'     => $wid + 4,
            'bordercolour' => $params{'red'},
            'absolutey'  => 1,
            'absolutex'  => 1,'absolutewidth'=>1,
            'href'       => $url,
        }));
    }
    return %coords;
}
1;
