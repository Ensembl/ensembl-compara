package Bio::EnsEMBL::GlyphSet::SE_generic_match;
use strict;
use Bio::EnsEMBL::GlyphSet;
@Bio::EnsEMBL::GlyphSet::SE_generic_match::ISA = qw(Bio::EnsEMBL::GlyphSet);
#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

sub init_label {
	my ($self) = @_;
	$self->init_label_text( 'Supp. evidence' );
}

sub _init {
	my ($self) = @_;
	my $offset = $self->{'container'}->start - 1;
	my $Config  = $self->{'config'};
	my $h             = 8;
#	my $colours       = $self->colours();
	my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
	my $pix_per_bp    = $Config->transform->{'scalex'};
	my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);

	$fontname = 'Tiny'; #this is hack since there is no config for Arial
	#warn Dumper($Config->texthelper);
	my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);		
	my $length  = $Config->container_width(); 
	my $all_matches = $Config->{'transcript'}{'evidence'};
	my $strand = $Config->{'transcript'}->{'transcript'}->strand;
	my $H = 0;

	#go through each combined hit, sorting on total length
	foreach my $hit_details (sort { $b->{'hit_length'} <=> $a->{'hit_length'} } values %{$all_matches} ) {
		my $start_x = 100000;
		my $finish_x = 0;
		my $hit_name = $hit_details->{'hit_name'};
		#go through each component of the combined hit (ie each supporting_feature)
		foreach my $block (@{$hit_details->{'data'}}) {
			$start_x = $start_x > $block->[0] ? $block->[0] : $start_x;
			$finish_x = $finish_x < $block->[1] ? $block->[1] : $finish_x;
			my $G = new Sanger::Graphics::Glyph::Rect({
				'x'         => $block->[0] ,
				'y'         => $H,
				'width'     => $block->[1]-$block->[0] +1,
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
				'y'         => $H + 0.5*$h,
				'width'     => $start_x,
				'height'    => 0,
				'absolutey' => 1,
				'colour'    => 'blue',
			}));
		}
		#draw extensions at the right of the image
		if (   ($hit_details->{'3_extension'} && $strand == 1)
			|| ($hit_details->{'5_extension'} && $strand == -1)) {
			$self->push(new Sanger::Graphics::Glyph::Line({
				'x'         => $finish_x + (1/$pix_per_bp),
				'y'         => $H + 0.5*$h,
				'width'     => $length-$finish_x,
				'height'    => 0,
				'absolutey' => 1,
				'colour'    => 'blue',
			}));
		}		

		if($Config->{'_add_labels'} ) {
			my  $T = length( $hit_name );
			my $width_of_label = $font_w_bp * ( $T ) * 1.5;
			$H += $font_h_bp + 2; #this is hack since there is no config for Arial
			$start_x -= $width_of_label/2; #also not sure about this as a way of setting the label to the far left of the feature
			my $tglyph = new Sanger::Graphics::Glyph::Text({
				'x'         => $start_x,
				'y'         => $H,
				'height'    => $font_h_bp,
				'width'     => $width_of_label,
				'font'      => $fontname,
				'colour'    => 'black',#$colour,
				'text'      => $hit_name,
				'absolutey' => 1,
			});

			$self->push($tglyph);
		}
		$H += 13; #this is yet another hack since there is no config for Arial
	}
}

1;
