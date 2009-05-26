package Bio::EnsEMBL::GlyphSet::TSE_legend;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) = @_;
    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 4;
    my $wuc           = $self->{'config'};
    my $im_width      = $wuc->image_width();
    my $o_type        = $wuc->cache('trans_object')->{'object_type'};

    my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
    my @res                    = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $th                     = $res[3];
    my $pix_per_bp             = $self->{'config'}->transform()->{'scalex'};	

    my $start_x;
    my ($x,$y) = (0,0.5);
    my $h      = 8;
    my $G;

    my $rect = $self->Rect({
	'x'             => 0,
	'y'             => $y,
	'width'         => $im_width,
	'height'        => 0,
	'colour'        => 'grey50',
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push($rect);

    #retrieve the features that were drawn and add legends for them
    my %features = $wuc->cache('legend') ? %{$wuc->cache('legend')} : ();
    foreach my $f (sort { $features{$a}->{'priority'} <=> $features{$b}->{'priority'} } keys %features) {
	my $colour = $features{$f}->{'colour'};
	my $db_type = $f;
	$db_type =~ s/cdna/cDNA/;
	$db_type =~ s/est/EST/;

	if($x==($NO_OF_COLUMNS)) {
	    $x = 0;
	    $y++;
	}

	#draw two exon hits and an intron for each feature type
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$h = $features{$f}->{'height'};
	my $G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y*$th - 1,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'colour'        => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});;
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x+$BOX_WIDTH,
	    'y'             => $y*$th + 2,
	    'h'             => 1,
	    'width'         => $BOX_WIDTH,
	    'colour'        => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Text({
	    'x'             => $start_x + 2*$BOX_WIDTH + 4,
	    'y'             => $y*$th - 5,
	    'height'        => $th,
	    'valign'        => 'center',
	    'halign'        => 'left',
	    'ptsize'        => $fontsize,
	    'font'          => $fontname,
	    'colour'        => 'black',
	    'text'          => "$db_type evidence",
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$x++;
    }
	
    $NO_OF_COLUMNS = 2;
    my $line_spacing = 1.2;
    my $two_box_offset = $line_spacing/1.7;

    #start new new line
    $y+=$line_spacing;
    $y+=$line_spacing;
    $x=0;

    my $top_y = $y;

    #Draw a red I-bar (non-canonical intron)
    $start_x = $im_width * $x/$NO_OF_COLUMNS;
    my $colour = $self->my_colour('non_can_intron');
    my $G = $self->Line({
	'x'             => $start_x,
	'y'             => $y*$th + 8,
	'width'         => $BOX_WIDTH,
	'height'        => 0,
	'colour'        => $colour,
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push( $G );
    $G = $self->Line({
	'x'             => $start_x,
	'y'             => $y*$th + 5,
	'width'         => 0,
	'height'        => 6,
	'colour'        => $colour,
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push( $G );
    $G = $self->Line({
	'x'             => $start_x + $BOX_WIDTH,
	'y'             => $y*$th +5,
	'width'         => 0,
	'height'        => 6,
	'colour'        => $colour,
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });	
    $self->push( $G );
    $G = $self->Text({
	'x'             => $start_x + $BOX_WIDTH + 4,
	'y'             => $y*$th,
	'height'        => $th,
	'valign'        => 'center',
	'halign'        => 'left',
	'ptsize'        => $fontsize,
	'font'          => $fontname,
	'colour'        => 'black',
	'text'          => 'non-canonical splice site',
	'absolutey'     => 0,
	'absolutex'     => 1,
	'absolutewidth' => 1
    });
    $self->push( $G );


   #draw legends for exon/CDS & hit mismatch (not for vega)
    my %dets;
    if ($o_type =~ /otter/) {
	%dets = ();
    }
    else {
	%dets = (
	    $self->my_colour('evi_short') => 'evidence start / ends within exon / CDS',
	    $self->my_colour('evi_long')  => 'evidence extends beyond exon / CDS',
	);
	$y+=$line_spacing;
	$y+=$two_box_offset;
    }

   foreach my $c (sort { $b cmp $a} keys %dets) {
	my $txt = $dets{$c};
	#draw red/blue lines on the ends of boxes
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$colour = 'black';
	$G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => ($y-(0.2*$two_box_offset))*$th,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);	
	$G = $self->Line({
	    'x'             => $start_x,
	    'y'             => ($y-(0.2*$two_box_offset))*$th,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);	
	$G = $self->Line({
	    'x'             => $start_x + 1,
	    'y'             => ($y-(0.2*$two_box_offset))*$th,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x + 2,
	    'y'             => ($y-(0.2*$two_box_offset))*$th,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	
	$G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => ($y+$two_box_offset)*$th,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);	
	$G = $self->Line({
	    'x'             => $start_x+$BOX_WIDTH-1,
	    'y'             => ($y+$two_box_offset)*$th,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x+$BOX_WIDTH-2,
	    'y'             => ($y+$two_box_offset)*$th,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);			
	$G = $self->Line({
	    'x'             => $start_x+$BOX_WIDTH,
	    'y'             => ($y+$two_box_offset)*$th,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Text({
	    'x'             => $start_x + $BOX_WIDTH + 4,
	    'y'             => $y*$th,
	    'height'        => $th,
	    'valign'        => 'center',
	    'halign'        => 'left',
	    'ptsize'        => $fontsize,
	    'font'          => $fontname,
	    'colour'        => 'black',
	    'text'          => $txt,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$y+=$line_spacing;
	$y+=$two_box_offset;
    }

    #start at the top of a new column
    $x++;
    $y=$top_y;
    #draw legends for exon/CDS & hit mismatch
    my $miss_col  = $self->my_colour('evi_missing');
    my $extra_col = $self->my_colour('evi_extra');
    %dets = ( $miss_col  => 'part of evidence missing from transcript structure' );
    unless ($o_type =~ /otter/) {
	$dets{$extra_col} = 'part of evidence duplicated in transcript structure';
    }

    foreach my $c (sort { $b cmp $a} keys %dets) {
	my $txt = $dets{$c};

	#draw two exons and a dotted  intron to identify hit mismatches
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	my $G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y*$th+6,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x + $BOX_WIDTH + 1,
      	    'y'             => $y*$th+10,
	    'h'             => 1,
	    'width'         => $BOX_WIDTH - 1,
	    'colour'        => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	    'dotted'        => 1,
	});
	$self->push($G);
	$G = $self->Rect({
	    'x'             => $start_x + 2*$BOX_WIDTH,
	    'y'             => $y*$th+6,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Text({
	    'x'             => $start_x + 3*$BOX_WIDTH + 4,
	    'y'             => $y*$th,
	    'height'        => $th,
	    'valign'        => 'center',
	    'halign'        => 'left',
	    'ptsize'        => $fontsize,
	    'font'          => $fontname,
	    'colour'        => 'black',
	    'text'          => $txt,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$y+=$line_spacing;
	$y+=$two_box_offset;

    }

    if( $o_type !~ /otter/ ) {

	#lines extending beyond the end of the hit
	$colour = $self->my_colour('evi_long');
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$G = $self->Line({
	    'x'             => $start_x,
	    'y'             => ($y-(0.2*$two_box_offset))*$th,
	    'height'        => $h,
	    'width'         => 0,
	    'colour'        => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);	
	$G = $self->Line({
	    'x'             => $start_x,
	    'y'             => ($y-(0.2*$two_box_offset))*$th + 3,
	    'h'             => 1,
	    'width'         => 2*$BOX_WIDTH,
	    'colour'        => $colour,
	    'dotted'        => 1,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);	
	$G = $self->Rect({
	    'x'             => $start_x + 2*$BOX_WIDTH,
	    'y'             => ($y-(0.2*$two_box_offset))*$th,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);

	$G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => ($y+$two_box_offset)*$th,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x + $BOX_WIDTH,
	    'y'             => ($y+$two_box_offset)*$th+3,
	    'h'             => 1,
	    'width'         => 2*$BOX_WIDTH,
	    'colour'        => $colour,
	    'dotted'        => 1,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x + 3*$BOX_WIDTH,
	    'y'             => ($y+$two_box_offset)*$th,
	    'height'        => $h,
	    'width'         => 0,
	    'colour'        => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
	$G = $self->Text({
	    'x'             => $start_x + 3*$BOX_WIDTH + 4,
	    'y'             => $y*$th,
	    'height'        => $th,
	    'valign'        => 'center',
	    'halign'        => 'left',
	    'ptsize'        => $fontsize,
	    'font'          => $fontname,
	    'colour'        => 'black',
	    'text'          => 'evidence extends beyond the end of the transcript',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$y+=$line_spacing;
    }
}

1;
