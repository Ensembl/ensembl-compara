package Bio::EnsEMBL::GlyphSet::Vannot_ig_and_ig_pseudo;
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
		'text'      => 'Ig Segment',				   
		'font'      => 'Small',
		'colour'	=> $Config->get( '_colours','Ig_Segment' ),
		'absolutey' => 1,
    });
    my $label2 = new Sanger::Graphics::Glyph::Text({
		'text'      => 'Ig Pseudo Seg.',
		'font'      => 'Small',
		'colour'	=>  $Config->get( '_colours','Ig_Pseudogene'),		
		'absolutey' => 1,
    });
		
    $self->label($label);
    $self->label2($label2);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
    my $known_col = $Config->get( '_colours','Ig_Segment') ;
    my $genes_col = $Config->get( '_colours','Ig_Pseudogene' ); 	

    my $known_genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'ig_segment');
    my $genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'ig_pseudogene');

    return unless  $known_genes->size() &&  $genes->size();


return if (($known_genes->size()==0) && ($genes->size()==0));

my $known_max = $known_genes->{'_biggest_value'} ;
my $genes_max = $genes->{'_biggest_value'} ;



return unless (($known_max > 0) || ($genes_max>0));

my $Hscale_factor = 1;
    if  (($genes_max > 0) && ($known_max > 0)){
	$Hscale_factor = ($known_max / $genes_max);
  } 


   	$genes->scale_to_fit( $Config->get( 'Vannot_ig_and_ig_pseudo', 'width' ) );
	$genes->stretch(0);
   	$known_genes->scale_to_fit( $Config->get( 'Vannot_ig_and_ig_pseudo', 'width' ) * $Hscale_factor );	
	$known_genes->stretch(0);
		

	my @genes = $genes->get_binvalues();
	my @known_genes = $known_genes->get_binvalues()  ;	

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
