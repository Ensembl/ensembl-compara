package Bio::EnsEMBL::GlyphSet::snp;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;

	return unless ($self->strand() == -1);
    my $y          = 0;
    my $h          = 8;
    my $highlights = $self->highlights();
	my $cmap  = new ColourMap;
	my $blue  = $cmap->id_by_name('blue');

    my @bitmap      = undef;
    my ($im_width, $im_height) = $Config->dimensions();
    my $bitmap_length = $VirtualContig->length();
    my $type = $Config->get($Config->script(),'gene','src');
    my @xf=$VirtualContig->get_all_ExternalFeatures();
	my @snp;
	
	## need to sort external features into SNPs or traces and treat them differently
	foreach my $f (@xf){
		if ($f->isa("Bio::EnsEMBL::ExternalData::Variation")) {
			# A SNP
			push(@snp, $f);
		} 
	}

	my $rect;
	my $colour;
    foreach my $s (@snp) {
		my $x = $s->start();
		#print STDERR "SNP start: ", $x, " ID:", $s->id(),  "\n";
		my $snpglyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      => $x,
			'y'      => 0,
			'width'  => 2,
			'height' => $h,
			'colour' => $blue,
			'absolutey'  => 1,
			'zmenu'     => { caption => $s->id() },
		});
		$self->push($snpglyph);
	}

}

1;
