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

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'SNP',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;


    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my $highlights    = $self->highlights();
    my $cmap          = new ColourMap;
    my $snp_col       = $Config->get($Config->script(),'snp','col');
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $type          = $Config->get($Config->script(),'gene','src');
    my @xf            = $VirtualContig->get_all_ExternalFeatures();
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
		my $id = $s->id();
		#print STDERR "SNP start: ", $x, " ID:", $s->id(),  "\n";
		my $snpglyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      => $x,
			'y'      => 0,
			'width'  => 2,
			'height' => $h,
			'colour' => $snp_col,
			'absolutey'  => 1,
            'zmenu'     => { 
                    'caption' => "$id",
                    'SNP properties' => "/perl/snpview?snp=$id",
                    'dbSNP data' => "http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?type=rs&rs=$id",
			},
		});
		$self->push($snpglyph);
	}

}

1;
