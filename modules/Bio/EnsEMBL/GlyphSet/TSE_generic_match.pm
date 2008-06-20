package Bio::EnsEMBL::GlyphSet::TSE_generic_match;
use strict;
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet::TSE_generic_match::ISA = qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;

sub init_label {
	my ($self) = @_;
	$self->init_label_text( 'T. Supp. evidence' );
}

sub _init {
	my ($self) = @_;
	my $Config     = $self->{'config'};
	my $h          = 8; #height of glyph

#	my $colours       = $self->colours();
	my $pix_per_bp = $Config->transform->{'scalex'};
	my $fontname   = $Config->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
	$fontname      = 'Tiny'; #this is hack since there is no config for Arial
	my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);
	#warn Dumper($Config->texthelper);
	
	my $length      = $Config->container_width(); 
	my $all_matches = $Config->{'transcript'}{'transcript_evidence'};
	my $strand      = $Config->{'transcript'}->{'transcript'}->strand;

	#go through each hit (transcript_supporting_feature)
	my $Y          = 0;
	foreach my $hit_details (sort { $b->{'hit_length'} <=> $a->{'hit_length'} } values %{$all_matches} ) {
		my $hit_name = $hit_details->{'hit_name'};
		my $start_x  = 1000000;
		my $finish_x = 0;

		#draw hit locations
		foreach my $block (@{$hit_details->{'data'}}) {
			my $width = $block->[1]-$block->[0] +1;
			$start_x  = $start_x  > $block->[0] ? $block->[0] : $start_x;
			$finish_x = $finish_x < $block->[1] ? $block->[1] : $finish_x;
			my $G = new Sanger::Graphics::Glyph::Rect({
				'x'         => $block->[0] ,
				'y'         => $Y,
				'width'     => $width,
				'height'    => $h,
				'bordercolour' => 'black',
				'absolutey' => 1,
				'title'     => $hit_name,
				'href'      => '',
			});		
			$self->push( $G );
		}

		#draw extensions at the left of the image
		if (   ($hit_details->{'5_extension'} && $strand == 1)
			|| ($hit_details->{'3_extension'} && $strand == -1)) {
			$self->push(new Sanger::Graphics::Glyph::Line({
				'x'         => 0,
				'y'         => $Y + 0.5*$h,
				'width'     => $start_x,
				'height'    => 0,
				'absolutey' => 1,
				'colour'    => 'blue',
			}));
		}
		#draw extensions at the right of the image
		if (   ($hit_details->{'3_extension'} && $strand == 1)
			|| ($hit_details->{'5_extension'} && $strand == -1)) {
			warn "x = $finish_x";
			$self->push(new Sanger::Graphics::Glyph::Line({
				'x'         => $finish_x + (1/$pix_per_bp),
				'y'         => $Y + 0.5*$h,
				'width'     => $length-$finish_x,
				'height'    => 0,
				'absolutey' => 1,
				'colour'    => 'blue',
			}));
		}			 

		if ($Config->{'_add_labels'}) {
			my  $T = length( $hit_name );
			my $width_of_label = $font_w_bp * ( $T ) * 1.5;
			$Y += $font_h_bp + 2; #this is hack (ie not scalable) since there is no config for Arial
			$start_x -= $width_of_label/2;
			my $tglyph = new Sanger::Graphics::Glyph::Text({
				'x'         => $start_x,
				'y'         => $Y,
				'height'    => $font_h_bp,
				'width'     => $width_of_label,
				'font'      => $fontname,
				'colour'    => 'black',#$colour,
				'text'      => $hit_name,
				'absolutey' => 1,
			});

			$self->push($tglyph);
		}
		$Y += 13; #this is another hack since there is no config for Arial
	}
}

1;
