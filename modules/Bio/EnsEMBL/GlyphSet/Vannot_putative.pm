package Bio::EnsEMBL::GlyphSet::Vannot_putative;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use SiteDefs;

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'};	
    my $label = new Sanger::Graphics::Glyph::Text({
		'text'      => 'Putative',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vannot_putative','col'),
		'absolutey' => 1,
    });
		
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
    my $putative     = $self->{'container'}->{'da'}->get_density_per_chromosome_type( $chr,'putative' );
    my $known_genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'known');
    return unless $known_genes->size && $putative->size(); 

return unless $putative->{'_biggest_value'} && $known_genes->{'_biggest_value'};


    my $Hscale_factor =$putative->{'_biggest_value'}/ $known_genes->{'_biggest_value'} ;

    my $putative_col = $Config->get( 'Vannot_putative','col' );
    $putative->scale_to_fit( $Config->get( 'Vannot_putative', 'width' ) * $Hscale_factor );
    $putative->stretch(0);
    my @putative = $putative->get_binvalues();

    foreach (@putative){
	    my $g_x = new Sanger::Graphics::Glyph::Rect({
		    'x'      => $_->{'chromosomestart'},
		    'y'      => 0,
		    'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
		    'height' => $_->{'scaledvalue'},
		    'bordercolour' => $putative_col,
		    'absolutey' => 1,
		    'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
	    });
	$self->push($g_x);
    }
}

1;
