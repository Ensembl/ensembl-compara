package Bio::EnsEMBL::GlyphSet::TSE_generic_match;
use strict;
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet::TSE_generic_match::ISA = qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;

sub init_label {
	my ($self) = @_;
	$self->init_label_text();#'Transcript evidence' );
}

sub _init {
	my ($self) = @_;
	my $Config     = $self->{'config'};
	my $h          = 8; #height of glyph

	my $colours       = $self->colours();
	my $pix_per_bp = $Config->transform->{'scalex'};
	my( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
	my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
#	warn Dumper($Config->texthelper);
	
	my $length      = $Config->container_width(); 
	my $all_matches = $Config->{'transcript'}{'transcript_evidence'};
	my $strand      = $Config->{'transcript'}->{'transcript'}->strand;

	my( $font_w_bp, $font_h_bp);

	my $legend_priority = 4;

	my @draw_end_lines;

	#go through each hit (transcript_supporting_feature)
	my $H          = 0;

	foreach my $hit_details (sort { $b->{'hit_length'} <=> $a->{'hit_length'} } values %{$all_matches} ) {
		my $hit_name = $hit_details->{'hit_name'};
		my $start_x  = 1000000;
		my $finish_x = 0;
		my $last_end = 0; #true/false (prevents drawing of line from first exon
		my $last_end_x = 0; #position of end of last box - needed to draw

		$Config->{'TSE_legend'}{'hit_feature'}{'found'}++;
		$Config->{'TSE_legend'}{'hit_feature'}{'priority'} = $legend_priority;
		$Config->{'TSE_legend'}{'hit_feature'}{'height'} = $h;

		my $align_url =  $Config->{'transcript'}->{'web_transcript'}->_url({
						'type'     => 'Transcript',
						'action'   => 'SupportingEvidenceAlignment',
						't'        =>  $Config->{'transcript'}->{'transcript'}->stable_id,
						'sequence' => $hit_name,
					});

		warn "me ",Dumper($align_url);

		my $last_mismatch = 0;
		my ($lh_ext,$rh_ext) = (0,0);
		#draw hit locations
		warn Dumper($hit_details->{'data'}) if ($hit_name eq 'Q5T087');

	BLOCK:
		foreach my $block (@{$hit_details->{'data'}}) {

			next BLOCK unless (defined(%$block));
#			warn Dumper($block) if ($hit_name eq 'NM_024848.1');

			#draw lhs extensions
			if ( my $mis = $block->{'lh-ext'} ) {
				$lh_ext = $mis;
				next BLOCK;
			}

			#draw rhs extensions (not tested)
			if ( my $mis = $block->{'rh-ext'} ) {
				my $G = new Sanger::Graphics::Glyph::Line({
					'x'          => $last_end_x,
					'y'         => $H + $h/2,
					'h'         =>1,
					'width'     => $Config->container_width() - $last_end_x,
					'title'     => $mis,
					'colour'    => 'red',
					'dotted'    => 1,
					'absolutey' => 1,});			
				$self->push($G);
				next BLOCK;
			}
							
#			warn "**block start = ",$block->{'munged_start'}," end = ",$block->{'munged_end'} if ($hit_name eq 'NM_024848.1');

			next BLOCK unless (my $exon = $block->{'exon'});
			my $exon_stable_id = $exon->stable_id;

			#only draw blocks for those that aren't extra exons
			my $hit = $block->{'extra_exon'};
			if ($hit) {
				$last_mismatch = $hit->seq_region_end - $hit->seq_region_start;
				next;
			}
			
			my $width = $block->{'munged_end'}-$block->{'munged_start'} +1;
			$start_x  = $start_x  > $block->{'munged_start'} ? $block->{'munged_start'} : $start_x;
			$finish_x = $finish_x < $block->{'munged_end'} ? $block->{'munged_end'} : $finish_x;

			my ($w,$x);
			if ($strand == 1) {
				$x = $last_end + (1/$pix_per_bp);
				$w = $block->{'munged_start'} - $last_end - (1/$pix_per_bp);
			}
			else {
				$x = $last_end;
				$w = $block->{'munged_start'} - $last_end;
			}

			if ($lh_ext) {
				#draw a red line with an I end
				my $G = new Sanger::Graphics::Glyph::Line({
					'x'         => 0,
					'y'         => $H + $h/2,
					'h'         =>1,
					'width'     => $start_x,
					'colour'    => 'red',
					'title'     => $lh_ext,
					'absolutey' => 1,
				    'dotted'    => 1});				
				$self->push($G);

				$G = new Sanger::Graphics::Glyph::Line({
					'x'         => 10,
					'y'         => $H,
					'height'    => $h,
					'width'     => 0,
					'colour'    => 'red',
					'absolutey' => 1,});				
				$self->push($G);
				$lh_ext = 0;
			}
				
			if ($last_end) {
 #			warn "1- drawing line from $x with width of $w";# if ($hit_name eq 'NM_024848.1');
				my $G = new Sanger::Graphics::Glyph::Line({
					'x'          => $x,
					'y'         => $H + $h/2,
					'h'         =>1,
					'width'     => $w,
					'colour'    => 'black',
					'absolutey' => 1,});

				#add attributes if there is a part of the hit missing, or an extra bit
				my $mismatch;
				if ( $block->{'hit_mismatch'} || $last_mismatch) {
					$mismatch = $last_mismatch ? $last_mismatch : $block->{'hit_mismatch'};
					$G->{'dotted'} = 1;
					$G->{'colour'} = 'red';
					$G->{'title'}  = $mismatch > 0 ? "Missing $mismatch bp of hit" : "Overlapping ".abs($mismatch)." bp of hit";
				}
				$self->push($G);				
			}

			$last_mismatch = $last_mismatch ? 0 : $last_mismatch;
			$last_end = $block->{'munged_end'};

			#draw the actual hit
			my $G = new Sanger::Graphics::Glyph::Rect({
				'x'         => $block->{'munged_start'} ,
				'y'         => $H,
				'width'     => $width,
				'height'    => $h,
				'bordercolour' => 'black',
				'absolutey' => 1,
				'title'     => $hit_name,
				'href'      => $align_url,
			});

			#save location of edge of box in case we need to draw a line to the end of it later
			my $last_end_x = $block->{'munged_start'}+ $width;

#			warn " 2 - drawing box from ",$block->{'munged_start'}," with width of $width";#  if ($hit_name eq 'NM_024848.1');;

			#second and third elements of $block define whether there is a mismatch between exon and hit boundries
			#(need some logic to add meaningfull terms to zmenu)
			if (my $gap = $block->{'left_end_mismatch'}) {
				my $c = $gap > 0 ? 'red' : 'blue';
				push @draw_end_lines, [$block->{'munged_start'},$H,$c];
				push @draw_end_lines, [$block->{'munged_start'}+1/$pix_per_bp,$H,$c];
				
				$G->{'title'} = "$hit_name ($gap)";
			}
			if (my $gap = $block->{'right_end_mismatch'}) {
				my $c = $gap > 0 ? 'red' : 'blue';
				push @draw_end_lines, [$block->{'munged_end'}-1/$pix_per_bp,$H,$c];
				push @draw_end_lines, [$block->{'munged_end'},$H,$c];
				$G->{'title'} = "$hit_name ($gap)";
			}
			$self->push( $G );
		}

		my @res = $self->get_text_width(0, "$hit_name", '', 'font'=>$fontname, 'ptsize'=>$fontsize);
		my $W = ($res[2])/$pix_per_bp;
		($font_w_bp, $font_h_bp) = ($res[2]/$pix_per_bp,$res[3]);

		my $tglyph = new Sanger::Graphics::Glyph::Text({
			'x'         => -$res[2],
			'y'         => $H,
			'height'    => $font_h_bp,
			'width'     => $res[2],
			'textwidth' => $res[2],
			'font'      => $fontname,
			'colour'    => 'blue',
			'text'      => $hit_name,
			'absolutey' => 1,
			'absolutex' => 1,
			'absolutewidth' => 1,
			'ptsize'    => $fontsize,
			'halign     '=> 'right',
		});
		$self->push($tglyph);

		$H += $font_h_bp + 4;
	}

	#draw lines for the exon / hit boundry mismatches (draw last so they're on top of everything else)
	foreach my $mismatch_line ( @draw_end_lines ) {
		my $G = new Sanger::Graphics::Glyph::Line({
			'x'         => $mismatch_line->[0] ,
			'y'         => $mismatch_line->[1],
			'width'     => 0,
			'height'    => $h,
			'colour'    => $mismatch_line->[2],
			'absolutey' => 1,
		});
		$self->push( $G );
	}
}

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('TSE_transcript','colours');
}




1;
