package Bio::EnsEMBL::GlyphSet::TSE_legend;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

sub _init {
    my ($self) = @_;

    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 2;

    my $Config        = $self->{'config'};
    my $im_width      = $Config->image_width();

    my $o_type = $Config->{'object_type'};

    my @colours;
    my ($x,$y) = (0,0);
    my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
    my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $th = $res[3];
    my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
	
    my $FLAG = 0;
    my $start_x;
    my $h = 8;
    my $G;
    #retrieve the features that were counted as they were drawn and add (two colum) legends for them
    my %features = $Config->{'TSE_legend'} ? %{$Config->{'TSE_legend'}} : ();
     foreach my $f (sort { $features{$a}->{'priority'} <=> $features{$b}->{'priority'} } keys %features) {
	$y = $y+0.5 if $x==0;
	my $colour = $features{$f}->{'colour'};
	my $db_type = $f;
	#draw two exon hits and an intron for each feature type
	$start_x = $im_width * $x/$NO_OF_COLUMNS;

	$h = $features{$f}->{'height'};
	my $G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y * ( $th + 3 ) - 1,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' =>1,
	});;
	$self->push($G);
	$G = $self->Line({
	    'x'             => $start_x+$BOX_WIDTH,
	    'y'             => $y * ( $th + 3 ) + 2,
	    'h'             => 1,
	    'width'         => $BOX_WIDTH,
	    'colour'        => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	$G = $self->Rect({
	    'x'             => $start_x + 2*$BOX_WIDTH,
	    'y'             => $y * ( $th + 3 ) - 1,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => $colour,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' =>1,
	});
	$self->push($G);
	$G = $self->Text({
	    'x'             => $start_x + 3*$BOX_WIDTH + 4,
	    'y'             => $y * $th,
	    'height'        => $th,
	    'valign'        => 'center',
	    'halign'        => 'left',
	    'ptsize'        => $fontsize,
	    'font'          => $fontname,
	    'colour'        => 'black',
	    'text'          => "$db_type evidence",
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' =>1,
	});
	$self->push($G);
	$x++;

	if($x==($NO_OF_COLUMNS)) {
	    $x=0;
	    $y++;
	}
    }
	
    # Draw a separating line to distinguish the above dynamic legend from the following static legend
    $y++;
    my $rect = $self->Rect({
	'x'         => 0,
	'y'         => $y * ( $th + 3 ),
	'width'     => $im_width,
	'height'    => 0,
	'colour'    => 'grey50',
	'absolutey' => 1,
	'absolutex' => 1,
	'absolutewidth'=>1,
    });
    $self->push($rect);

    #start new line
    $y++;
    $x = 0;

    #Draw a red I-bar (non-canonical intron)
    $start_x = $im_width * $x/$NO_OF_COLUMNS;
    my $colour = 'red';
    my $G = $self->Line({
	'x'         => $start_x,
	'y'         => $y * ( $th + 3 ) + 2,
	'width'     => $BOX_WIDTH,
	'height'    => 0,
	'colour'    => $colour,
	'absolutey' => 1,
	'absolutex' => 1,
	'absolutewidth'=>1,
    });
    $self->push( $G );
    $G = $self->Line({
	'x'         => $start_x,
	'y'         => $y * ( $th + 3 ) - 1,
	'width'     => 0,
	'height'    => 6,
	'colour'    => $colour,
	'absolutey' => 1,
	'absolutex' => 1,
	'absolutewidth'=>1,
    });
    $self->push( $G );
    $G = $self->Line({
	'x'             => $start_x + $BOX_WIDTH,
	'y'             => $y * ( $th + 3 ) - 1,
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
	'y'             => $y * $th + 2,
	'height'        => $th,
	'valign'        => 'center',
	'halign'        => 'left',
	'ptsize'        => $fontsize,
	'font'          => $fontname,
	'colour'        => 'black',
	'text'          => 'non canonical splice site',
	'absolutey'     => 0,
	'absolutex'     => 1,
	'absolutewidth' => 1
    });
    $self->push( $G );

    if( $o_type ne 'vega' ) {
	$x++;

	#lines extending beyond the end of the hit
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$G = $self->Line({
	    'x'         => $start_x,
	    'y'         =>  $y * ( $th + 3 ) - 2,
	    'height'    => $h,
	    'width'     => 0,
	    'colour'    => 'red',
	    'absolutey' => 1,
	    'absolutex'     => 1,
	'absolutewidth' => 1,});				
	$self->push($G);
	
	$G = $self->Line({
	    'x'         => $start_x,
	    'y'         => $y * ( $th + 3 ) + 2,
	    'h'         => 1,
	    'width'     => 1.5*$BOX_WIDTH,
	    'colour'    => 'red',
	    'dotted'    => 1,
	    'absolutey' => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
	
	$G = $self->Rect({
	    'x'             => $start_x + 1.5*$BOX_WIDTH,
	    'y'             => $y * ( $th + 3 ) - 2,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);

	$y += 0.8;

	$G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y * ( $th + 3 ) - 2,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	
	$G = $self->Line({
	    'x'         => $start_x + $BOX_WIDTH,
	    'y'         => $y * ( $th + 3 ) + 2,
	    'h'         => 1,
	    'width'     => 1.5*$BOX_WIDTH,
	    'colour'    => 'red',
	    'dotted'    => 1,
	    'absolutey' => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
    
	$G = $self->Line({
	    'x'         => $start_x + 2.5*$BOX_WIDTH,
	    'y'         =>  $y * ( $th + 3 ) - 2,
	    'height'    => $h,
	    'width'     => 0,
	    'colour'    => 'red',
	    'absolutey' => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
	
	$G = $self->Text({
	    'x'             => $start_x + 2.5*$BOX_WIDTH + 4,
	    'y'             => $y * $th -2,
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
	$y += 1.5;
    }
    else { $y++; }

    #new line
    $y += 1.5;
    $x=0;

    #draw legends for exon/CDS & hit mismatch
    my %dets = (	'red'  => 'part of evidence missing from transcript structure' );
    unless ($o_type eq 'vega') {
	$dets{'blue'} = 'part of evidence duplicated in transcript structure';
    }

    foreach my $c (sort { $b cmp $a} keys %dets) {
	my $txt = $dets{$c};

	#draw two exons and a dotted  intron to identify hit mismatches
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	my $G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y * ( $th + 3 ) - 2,
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
	    'y'             => $y * ( $th + 3 ) + 2,
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
	    'y'             => $y * ( $th + 3 ) - 2,
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
	    'y'             => $y * $th + 8,
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
	
	$x++;
    }

    #new line
    $y += 1.5;
    $x = 0;
    
    #draw legends for exon/CDS & hit mismatch (not for vega)
    if ($o_type eq 'vega') {
	%dets = ();
    }
    else {
	%dets = (
	    'blue' => 'evidence start / ends within exon / CDS',
	    'red'  => 'evidence extends beyond exon / CDS',
	);
    }

    foreach my $c (sort { $b cmp $a} keys %dets) {
	my $txt = $dets{$c};
	
	#draw red/blue lines on the ends of boxes
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$colour = 'black';
	$G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y * ( $th + 3 ) - 1,
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
	    'y'             => $y * ( $th + 3 ) - 1,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'         => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	
	$G = $self->Line({
	    'x'             => $start_x + 1,
	    'y'             => $y * ( $th + 3 ) - 1,
	    'width'         => 0,
	    'height'        => $h,
	    'colour'         => $c,
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	
	$y += 0.8;
	
	$G = $self->Rect({
	    'x'             => $start_x,
	    'y'             => $y * ( $th + 3 ) - 1,
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
	    'y'             => $y * ( $th + 3 ) - 1,
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
	    'y'             => $y * ( $th + 3 ) - 1,
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
	    'y'             => $y * $th + 5,
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
	$x++;
	$y -= 0.8;
    }

    if ($o_type ne 'vega') {
	$x=0;
	$y += 2.3;

	#lines extending beyond the end of the hit
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$G = new Sanger::Graphics::Glyph::Line({
	    'x'         => $start_x,
	    'y'         =>  $y * ( $th + 3 ) - 2,
	    'height'    => $h,
	    'width'     => 0,
	    'colour'    => 'red',
	    'absolutey' => 1,
	    'absolutex'     => 1,
	'absolutewidth' => 1,});				
	$self->push($G);
	
	$G = new Sanger::Graphics::Glyph::Line({
	    'x'         => $start_x,
	    'y'         => $y * ( $th + 3 ) + 2,
	    'h'         => 1,
	    'width'     => 1.5*$BOX_WIDTH,
	    'colour'    => 'red',
	    'dotted'    => 1,
	    'absolutey' => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
	
	$G = new Sanger::Graphics::Glyph::Rect({
	    'x'             => $start_x + 1.5*$BOX_WIDTH,
	    'y'             => $y * ( $th + 3 ) - 2,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);

	$y += 0.8;

	$G = new Sanger::Graphics::Glyph::Rect({
	    'x'             => $start_x,
	    'y'             => $y * ( $th + 3 ) - 2,
	    'width'         => $BOX_WIDTH,
	    'height'        => $h,
	    'bordercolour'  => 'black',
	    'absolutey'     => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	});
	$self->push($G);
	
	$G = new Sanger::Graphics::Glyph::Line({
	    'x'         => $start_x + $BOX_WIDTH,
	    'y'         => $y * ( $th + 3 ) + 2,
	    'h'         => 1,
	    'width'     => 1.5*$BOX_WIDTH,
	    'colour'    => 'red',
	    'dotted'    => 1,
	    'absolutey' => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
    
	$G = new Sanger::Graphics::Glyph::Line({
	    'x'         => $start_x + 2.5*$BOX_WIDTH,
	    'y'         =>  $y * ( $th + 3 ) - 2,
	    'height'    => $h,
	    'width'     => 0,
	    'colour'    => 'red',
	    'absolutey' => 1,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,});				
	$self->push($G);
	
	$G = new Sanger::Graphics::Glyph::Text({
	    'x'             => $start_x + 2.5*$BOX_WIDTH + 4,
	    'y'             => $y * $th + 10,
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
    }

}

1;
