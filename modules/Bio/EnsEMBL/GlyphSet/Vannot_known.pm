package Bio::EnsEMBL::GlyphSet::Vannot_known;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'};	
    my $label = new Sanger::Graphics::Glyph::Text({
		'text'      => 'Known',
		'font'      => 'Small',
		'colour'	=> $Config->get('_colours','Known'),
		'absolutey' => 1,
    });
		
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
    my $gene     = $self->{'container'}->{'da'}->get_density_per_chromosome_type( $chr,'known' );
    return unless $gene->size(); 



    my $gene_col = $Config->get('_colours','Known');
    $gene->scale_to_fit( $Config->get( 'Vannot_known', 'width' ) );
    $gene->stretch(0);
    my @gene = $gene->get_binvalues();

    foreach (@gene){
	    my $g_x = new Sanger::Graphics::Glyph::Rect({
		    'x'      => $_->{'chromosomestart'},
		    'y'      => 0,
		    'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
		    'height' => $_->{'scaledvalue'},
		    'bordercolour' => $gene_col,
		    'absolutey' => 1,
		    'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
	    });
	$self->push($g_x);
    }
}

1;
