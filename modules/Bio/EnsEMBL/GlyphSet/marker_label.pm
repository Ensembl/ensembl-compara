package Bio::EnsEMBL::GlyphSet::marker_label;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use  Sanger::Graphics::Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my $self = shift;
    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($VirtualContig->length() * $pix_per_bp);
    my @bitmap;

    return unless ($self->strand() == -1);

    my $feature_colour = $Config->get('marker','col');
    my $fontname       = "Tiny";
    my ($w,$h)         = $Config->texthelper->px2bp($fontname);
    $w = $Config->texthelper->width($fontname);

    foreach my $f (@{$VirtualContig->get_landmark_MarkerFeatures()}){
	my $fid = $f->display_label();
	my $bp_textwidth = $w * length("$fid ");
	my $glyph = new Sanger::Graphics::Glyph::Text({
		'x'	    => $f->start()-1,
		'y'	    => 0,
		'height'    => $Config->texthelper->height($fontname),
		'font'	    => $fontname,
		'colour'    => $feature_colour,
		'absolutey' => 1,
		'text'	    => $fid,
        'href'      => "/$ENV{'ENSEMBL_SPECIES'}/markerview?marker=$fid",

		});

	##############
    	# bump-tastic
	#
    	my $bump_start = int($glyph->x() * $pix_per_bp);
	$bump_start    = 0 if ($bump_start < 0);

    	my $bump_end = $bump_start + $bp_textwidth;
    	next if $bump_end > $bitmap_length;
    	my $row = & Sanger::Graphics::Bump::bump_row(      
	    $bump_start,
	    $bump_end,
	    $bitmap_length,
	    \@bitmap
    	);

    	$glyph->y($glyph->y() + (1.2 * $row * $h));
    	$self->push($glyph);
    }	
}

1;
