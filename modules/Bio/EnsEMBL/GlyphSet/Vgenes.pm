package Bio::EnsEMBL::GlyphSet::Vgenes;
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
    $self->label(new Sanger::Graphics::Glyph::Text({
	        'text'      => 'Known Genes',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vgenes','col_known'),
		'absolutey' => 1,
    }));
    $self->label2(new Sanger::Graphics::Glyph::Text({
		'text'      => 'Genes',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vgenes','col_genes'),		
		'absolutey' => 1,
    }));
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
   	my $genes_col = $Config->get( 'Vgenes','col_genes' );
   	my $known_col = $Config->get( 'Vgenes','col_known' );
	
	
    my $known_genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'kngene');
    my $genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'gene');

    return unless $known_genes->size() && $genes->size();

	my $Hscale_factor = $known_genes->{'_biggest_value'} / $genes->{'_biggest_value'};

   	$genes->scale_to_fit( $Config->get( 'Vgenes', 'width' ) );
	$genes->stretch(0);
   	$known_genes->scale_to_fit( $Config->get( 'Vgenes', 'width' ) * $Hscale_factor );	
	$known_genes->stretch(0);
		

	my @genes = $genes->get_binvalues();
	my @known_genes = $known_genes->get_binvalues();	

    foreach (@genes){
		my $known_gene = shift @known_genes;	
	    my $g_x = new Sanger::Graphics::Glyph::Rect({
			'x'      => $known_gene->{'chromosomestart'},
			'y'      => 0,
			'width'  => $known_gene->{'chromosomeend'}-$_->{'chromosomestart'},
			'height' => $known_gene->{'scaledvalue'},
			'colour' => $known_col,
			'absolutey' => 1,
		});
	    $self->push($g_x);
		$g_x = new Sanger::Graphics::Glyph::Rect({
			'x'      => $_->{'chromosomestart'},
			'y'      => 0,
			'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
			'height' => $_->{'scaledvalue'},
			'bordercolour' => $genes_col,
			'absolutey' => 1,
			'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
		});
	    $self->push($g_x);
	}
}

1;
