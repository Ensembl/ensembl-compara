package Bio::EnsEMBL::GlyphSet::TSE_legend;

use strict;
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

use Data::Dumper;
#$Data::Dumper::Maxdepth = 2;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    $self->init_label_text( 'Legend' );
}

sub _init {
    my ($self) = @_;

    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 2;

    my $Config        = $self->{'config'};
    my $im_width      = $Config->image_width();

    my @colours;
    my ($x,$y) = (0,0);
    my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
    my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $th = $res[3];
    my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
	
    my $FLAG = 0;
    my $start_x;
    my $h = 8;

    #retrieve the features that were counted as they were drawn and add (two colum) legends for them
    my %features = %{$Config->{'TSE_legend'}};	
    foreach my $f (sort { $features{$a}->{'priority'} <=> $features{$b}->{'priority'} } keys %features) {
	$y++ if $x==0;

	#    @colours = @{$features{$_}->{'legend'}};
	#    while( my ($legend, $colour) = splice @colours, 0, 2 ) {
	#      $FLAG = 1;
	#      my $tocolour='';
	#      ($tocolour,$colour) = ($1,$2) if $colour =~ /(.*):(.*)/;

	my $colour = 'black';

	#draw two exon hits and an intron for each feature type
	if ($f =~ /hit_feature/) {
	    $start_x = $im_width * $x/$NO_OF_COLUMNS;
	    $h = $features{$f}->{'height'};
	    my $G = new Sanger::Graphics::Glyph::Rect({
		'x'             => $start_x,
		'y'             => $y * ( $th + 3 ) - 1,
		'width'         => $BOX_WIDTH,
		'height'        => $h,
		'bordercolour'  => $colour,
		'absolutey'     => 1,
		'absolutex'     => 1,
		'absolutewidth' =>1,
	    });
	    $self->push($G);
	    $G = new Sanger::Graphics::Glyph::Line({
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
	    $G = new Sanger::Graphics::Glyph::Rect({
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
	    $G = new Sanger::Graphics::Glyph::Text({
		'x'             => $start_x + 3*$BOX_WIDTH + 4,
		'y'             => $y * $th,
		'height'        => $th,
		'valign'        => 'center',
		'halign'        => 'left',
		'ptsize'        => $fontsize,
		'font'          => $fontname,
		'colour'        => 'black',
		'text'          => 'feature supporting intron - exon structure',
		'absolutey'     => 1,
		'absolutex'     => 1,
		'absolutewidth' =>1,
	    });
	    $self->push($G);
	    $x++;
	}
	
	if($x==$NO_OF_COLUMNS) {
	    $x=0;
	    $y++;
	}
    }
	
    # Draw a separating line to distinguish the above dynamic legend from the following static legend
    $y++;
    my $rect = new Sanger::Graphics::Glyph::Rect({
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
    my $G = new Sanger::Graphics::Glyph::Line({
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
    $G = new Sanger::Graphics::Glyph::Line({
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
    $G = new Sanger::Graphics::Glyph::Line({
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
    $G = new Sanger::Graphics::Glyph::Text({
	'x'             => $start_x + $BOX_WIDTH + 4,
	'y'             => $y * $th + 4,
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
    $x++;
    
    #draw two exons and a dotted red intron to identify hit mismatch
    $start_x = $im_width * $x/$NO_OF_COLUMNS;
    $colour = 'black';
    my $G = new Sanger::Graphics::Glyph::Rect({
	'x'             => $start_x,
	'y'             => $y * ( $th + 3 ) - 2,
	'width'         => $BOX_WIDTH,
	'height'        => $h,
	'bordercolour'  => $colour,
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push($G);
    $G = new Sanger::Graphics::Glyph::Line({
	'x'             => $start_x + $BOX_WIDTH + 1,
	'y'             => $y * ( $th + 3 ) + 2,
	'h'             => 1,
	'width'         => $BOX_WIDTH - 1,
	'colour'        => 'red',
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
	'dotted'        => 1,
    });
    $self->push($G);
    $G = new Sanger::Graphics::Glyph::Rect({
	'x'             => $start_x + 2*$BOX_WIDTH,
	'y'             => $y * ( $th + 3 ) - 2,
	'width'         => $BOX_WIDTH,
	'height'        => $h,
	'bordercolour'  => $colour,
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push($G);
    $G = new Sanger::Graphics::Glyph::Text({
	'x'             => $start_x + 3*$BOX_WIDTH + 4,
	'y'             => $y * $th + 4,
	'height'        => $th,
	'valign'        => 'center',
	'halign'        => 'left',
	'ptsize'        => $fontsize,
	'font'          => $fontname,
	'colour'        => 'black',
	'text'          => 'supporting feature not continuous over intron',
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push($G);
	
    #new line
    $y += 1.5;
    $x = 0;
	
    #draw legends for exon/CDS & hit mismatch
    my %dets = (
	'blue' => 'supporting feature start / ends within exon / CDS',
	'red'  => 'supporting feature extends beyond exon / CDS',
    );
    
    while (my ($c, $txt) = each %dets) {
	#foreach (my $i=0; $i< 2; $i++) {
	
	#my $txt = $i ? 'supporting feature start / ends within exon' : 'supporting feature extends beyond exon';
	#my $c = $i ? 'blue' : 'red';
	
	#draw red/blue lines on the ends of boxes
	$start_x = $im_width * $x/$NO_OF_COLUMNS;
	$colour = 'black';
	$G = new Sanger::Graphics::Glyph::Rect({
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
	
	$G = new Sanger::Graphics::Glyph::Line({
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
	
	$G = new Sanger::Graphics::Glyph::Line({
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
	
	$G = new Sanger::Graphics::Glyph::Rect({
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
	
	$G = new Sanger::Graphics::Glyph::Line({
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
	
	$G = new Sanger::Graphics::Glyph::Line({
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
	
	$G = new Sanger::Graphics::Glyph::Text({
	    'x'             => $start_x + $BOX_WIDTH + 4,
	    'y'             => $y * $th + 2,
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

    $y += 2.3;
    $start_x = 0;


    #lines extending beyond the end of the hit

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
	'bordercolour'  => $colour,
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
	'bordercolour'  => $colour,
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
	'y'             => $y * $th + 7,
	'height'        => $th,
	'valign'        => 'center',
	'halign'        => 'left',
	'ptsize'        => $fontsize,
	'font'          => $fontname,
	'colour'        => 'black',
	'text'          => 'supporting feature extends beyond the end of the transcript',
	'absolutey'     => 1,
	'absolutex'     => 1,
	'absolutewidth' => 1,
    });
    $self->push($G);
}

1;
