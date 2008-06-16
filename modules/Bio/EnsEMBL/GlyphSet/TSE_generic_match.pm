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
	my $offset = $self->{'container'}->start - 1;
	my $Config  = $self->{'config'};
	#	use Carp qw(cluck);
	#	cluck 'ere';
	my $y             = 0;
	my $h             = 8;
#	my $colours       = $self->colours();
	my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'};
	my $pix_per_bp    = $Config->transform->{'scalex'};
	my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);
	
	my $length  = $Config->container_width(); 
	my $all_matches = $Config->{'transcript'}{'transcript_evidence'};
	my $H = 0;

#	warn Dumper($all_matches);
#	while (my ($hit_name,$hit_details) = each %{$all_matches}) {
	foreach my $hit_details (sort { $b->{'hit_length'} <=> $a->{'hit_length'} } values %{$all_matches} ) {
		foreach my $block (@{$hit_details->{'data'}}) {
			my $G = new Sanger::Graphics::Glyph::Rect({
				'x'         => $block->[0] ,
				'y'         => $H,
				'width'     => $block->[1]-$block->[0] +1,
				'height'    => $h,
				'bordercolour' => 'black',
				'absolutey' => 1,
				'title'     => $hit_details->{'hit_name'},
				'href'      => '',
			});		
			$self->push( $G );
		}
		$H += 10;
	}
}

1;
