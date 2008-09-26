package Bio::EnsEMBL::GlyphSet::TSE_generic_match;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) = @_;
    my $all_matches = $self->cache('align_object')->{'transcript_evidence'};
    $self->draw_glyphs($all_matches);
}

sub draw_glyphs {
    my $self         = shift;
    my $all_matches  = shift;
    my $wuc          = $self->{'config'};
    my $h            = 8; #height of glyph
    my $pix_per_bp   = $wuc->transform->{'scalex'};
    my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
    my($font_w_bp, $font_h_bp) = $wuc->texthelper->px2bp($fontname);	
    my $length       = $wuc->container_width(); 
    my $strand       = $wuc->cache('trans_object')->{'transcript'}->strand;

    my( $font_w_bp, $font_h_bp);
    my $legend_priority = 4;
    my $H               = 0;
    my @draw_end_lines;

    my $legend;
    #go through each parsed transcript_supporting_feature
    foreach my $hit_details (sort { $b->{'hit_length'} <=> $a->{'hit_length'} } values %{$all_matches} ) {
	my $hit_name = $hit_details->{'hit_name'};
	my $hit_type = $hit_details->{'hit_type'};
	my $hit_db   = $hit_details->{'hit_db'};
	my $start_x  = 1000000;
	my $finish_x = 0;
	my $last_end = 0; #true/false (prevents drawing of line from first exon)
	my $last_end_x = 0; #position of end of last box - needed to draw line
	my ($lh_ext,$rh_ext) = (0,0); #booleans for drawing of extensions to lh or rh side of image
	my $last_mismatch = 0; #will be set to the label for the amount of mismatch, but also defines whether the line is drawn
	my $colour = $self->my_colour($hit_type);

	#used for legend
	
	$legend->{$hit_type}{'found'}++;
	$legend->{$hit_type}{'priority'} = $legend_priority;
	$legend->{$hit_type}{'height'}   = $h;
	$legend->{$hit_type}{'colour'}   = $colour;

      BLOCK:
	foreach my $block (@{$hit_details->{'data'}}) {
	    next BLOCK unless (defined(%$block));
#	    warn Dumper($block) if ($hit_name eq 'Q8TC21.1');

	    my $c = $self->my_colour('evi_long');
	    #draw lhs extensions from the next block (first block is always just lhs)
	    if ( my $mis = $block->{'lh-ext'} ) {
		$lh_ext = $mis;
	    }
	    #draw rhs extensions (only last block can be a rhs extension)
	    if ( my $mis = $block->{'rh-ext'} ) {
		if ($block->{'exon'}) {
		    $last_end_x = $block->{'munged_end'};
		}
		my $G = $self->Line({
		    'x'         => $last_end_x,
		    'y'         => $H + $h/2,
		    'h'         => 1,
		    'width'     => $wuc->container_width() - $last_end_x,
		    'title'     => "Evidence extends $mis bp beyond the end of the transcript",
		    'colour'    => $c,
		    'dotted'    => 1,
		    'absolutey' => 1,});			
		$self->push($G);

		$G = $self->Line({
		    'x'         => $wuc->container_width(),
		    'y'         => $H,
		    'height'    => $h,
		    'width'     => 0,
		    'colour'    => $c,
		    'absolutey' => 1,});				
		$self->push($G);

	    }
	    next BLOCK unless (my $exon = $block->{'exon'});

	    #allow a hit mismatch to be drawn next time for 'extra exons'
	    my $hit = $block->{'extra_exon'};
	    if ($hit) {
		$last_mismatch = $hit->seq_region_end - $hit->seq_region_start;
		next;
	    }

	    #calculate positions of the 'exon' block
	    my $width = $block->{'munged_end'} - $block->{'munged_start'};
	    $start_x  = $start_x  > $block->{'munged_start'} ? $block->{'munged_start'} : $start_x;
	    $finish_x = $finish_x < $block->{'munged_end'}   ? $block->{'munged_end'}   : $finish_x;

	    #draw an I line for a lh extension
	    if ($lh_ext) {
		my $G = $self->Line({
		    'x'         => 0,
		    'y'         => $H + $h/2,
		    'h'         => 1,
		    'width'     => $start_x,
		    'colour'    => $c,
		    'title'     => "Evidence extends $lh_ext bp beyond the end of the transcript",
		    'absolutey' => 1,
		    'dotted'    => 1});				
		$self->push($G);
		
		$G = $self->Line({
		    'x'         => 0,
		    'y'         => $H,
		    'height'    => $h,
		    'width'     => 0,
		    'colour'    => $c,
		    'absolutey' => 1,});				
		$self->push($G);
		$lh_ext = 0;
	    }

	    #draw a line back to the last exon end
	    if ($last_end) {
		my ($w,$x);
		if ($strand == 1) {
		    $x = $last_end + (1/$pix_per_bp);
		    $w = $block->{'munged_start'} - $last_end - (1/$pix_per_bp);
		}
		else {
		    $x = $last_end;
		    $w = $block->{'munged_start'} - $last_end;
		}
#		warn "1- drawing line from $x with width of $w" if ($hit_name eq 'Q4R8S0.1');
		my $G = $self->Line({
		    'x'         => $x,
		    'y'         => $H + $h/2,
		    'h'         => 1,
		    'colour'    => $colour,
		    'width'     => $w,
		    'absolutey' => 1,});

		#add attributes if there is a part of the hit missing, or an extra bit
		my $mismatch;
		if ( $block->{'hit_mismatch'} || $last_mismatch) {
		    $mismatch = $last_mismatch ? $last_mismatch : $block->{'hit_mismatch'};
		    $G->{'dotted'} = 1;
		    $G->{'colour'} = $mismatch > 0 ? $self->my_colour('evi_missing') : $self->my_colour('evi_extra');
		    $G->{'title'}  = $mismatch > 0 ? "$mismatch bp of $hit_name missing" : abs($mismatch)." bp of $hit_name overlaps";
		}
		$self->push($G);				
	    }

	    $last_mismatch = $last_mismatch ? 0 : $last_mismatch;
	    $last_end = $block->{'munged_end'};


	    #save location of edge of box in case we need to draw a line to the end of it later
	    $last_end_x = $block->{'munged_start'}+ $width;

	    my $zmenu_dets = {
		'type'        => 'Transcript',
		'action'      => 'SupportingEvidence/Alignment',
		't'           => $wuc->cache('trans_object')->{'transcript'}->stable_id,
		'sequence'    => $hit_name,
		'hit_db'      => $hit_db,
		'hit_length'  => $block->{'hit_length'},
		'exon'        => $exon->stable_id,
		'exon_length' => $block->{'exon_length'},
	    };

	    #if there is a mismatch between exon and hit boundries then add a zmenu entry and also
	    #note the position for drawing coloured lines later
	    if (my $gap = $block->{'left_end_mismatch'}) {
		my $c = $gap > 0 ? $self->my_colour('evi_long') : $self->my_colour('evi_short');
		push @draw_end_lines, [$block->{'munged_start'},$H,$c];
		push @draw_end_lines, [$block->{'munged_start'}+1/$pix_per_bp,$H,$c];
		push @draw_end_lines, [$block->{'munged_start'}+2/$pix_per_bp,$H,$c];
		
		if ($strand > 0) {
		    $zmenu_dets->{'five_end_mismatch'} = $gap;
		}
		else {
		    $zmenu_dets->{'three_end_mismatch'} = $gap;
		}		
	    }
	    if (my $gap = $block->{'right_end_mismatch'}) {
		my $c = $gap > 0 ? $self->my_colour('evi_long') : $self->my_colour('evi_short');
		push @draw_end_lines, [$block->{'munged_start'}+$width-2/$pix_per_bp,$H,$c];
		push @draw_end_lines, [$block->{'munged_start'}+$width-1/$pix_per_bp,$H,$c];
		push @draw_end_lines, [$block->{'munged_start'}+$width,$H,$c];

		if ($strand > 0) {
		    $zmenu_dets->{'three_end_mismatch'} = $gap;
		}
		else {
		    $zmenu_dets->{'five_end_mismatch'} = $gap;
		}		
	    }

	    ##draw the actual hit
	    my $G = $self->Rect({
		'x'            => $block->{'munged_start'} ,
		'y'            => $H,
		'width'        => $width,
		'height'       => $h,
		'colour'       => $colour,
		'absolutey'    => 1,
		'title'        => $hit_name,
		'href'         => $self->_url($zmenu_dets),
	    });

	    $self->push( $G );
	}

	#label the hit (alignment needs fixing)
	my @res = $self->get_text_width(0, "$hit_name", '', 'font'=>$fontname, 'ptsize'=>$fontsize);
	my $W = ($res[2])/$pix_per_bp;
	($font_w_bp, $font_h_bp) = ($res[2]/$pix_per_bp,$res[3]);	
	my $tglyph = $self->Text({
	    'x'         => -$res[2],
	    'y'         => $H,
	    'height'    => $font_h_bp,
	    'width'     => $res[2],
	    'textwidth' => $res[2],
	    'font'      => $fontname,
	    'colour'    => 'black',
	    'text'      => $hit_name,
	    'absolutey' => 1,
	    'absolutex' => 1,
	    'absolutewidth' => 1,
	    'ptsize'    => $fontsize,
	    'halign'    => 'right',
	    });
	$self->push($tglyph);
	$H += $font_h_bp + 4;
    }

    #draw lines for the exon / hit boundry mismatches (draw last so they're on top of everything else)
    foreach my $mismatch_line ( @draw_end_lines ) {
	my $G = $self->Line({
	    'x'         => $mismatch_line->[0] ,
	    'y'         => $mismatch_line->[1],
	    'width'     => 0,
	    'height'    => $h,
	    'colour'    => $mismatch_line->[2],
	    'absolutey' => 1,
	});
	$self->push( $G );
    }
    $wuc->cache('legend',$legend)
}

1;
