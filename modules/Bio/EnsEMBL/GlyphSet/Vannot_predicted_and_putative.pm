package Bio::EnsEMBL::GlyphSet::Vannot_predicted_and_putative;
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
    my $chr      = $self->{'container'}->{'chr'};


 my $genecount1 = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'putative');
my $genecount2 = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'predicted');
my $text1 = ""; my $text2 = "";

    if ($genecount1->{'_biggest_value'}) { $text1  = 'Putative';  }
    if ($genecount2->{'_biggest_value'}) {$text2 = 'Predicted'; }

 my $label = new Sanger::Graphics::Glyph::Text({
		'text'      => $text1,
		'font'      => 'Small',
		'colour'	=> $Config->get( '_colours','Putative' ),
		'absolutey' => 1,
    }); $self->label($label);

 my $label2 = new Sanger::Graphics::Glyph::Text({
		'text'      => $text2,
		'font'      => 'Small',
		'colour'	=>  $Config->get( '_colours','Predicted_Gene' ),		
		'absolutey' => 1,
    }); $self->label2($label2);

}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
   


    my $known_col = $Config->get( '_colours','Predicted_Gene' );
    my $genes_col = $Config->get( '_colours','Putative' );

    my $known_genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'predicted');

    my $genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'putative');


   
 return unless  ($known_genes->size() ||  $genes->size());


    my $known_max = ($known_genes->{'_biggest_value'} || 0)  ;
    my $genes_max = ($genes->{'_biggest_value'} ||0) ;


return unless (($known_max > 0) || ($genes_max >0));


my $Hscale_factor = 1;
    if  (($genes_max > 0) && ($known_max > 0)){
	$Hscale_factor = ($known_max / $genes_max);
  } 

   	$genes->scale_to_fit( $Config->get( 'Vannot_predicted_and_putative', 'width' ) );
	$genes->stretch(0);

   	$known_genes->scale_to_fit( $Config->get( 'Vannot_predicted_and_putative', 'width' ) * $Hscale_factor );

    $known_genes->stretch(0);
	
    my @genes = $genes->get_binvalues() ;
    my @known_genes = $known_genes->get_binvalues() ;
    

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
			'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'} ,
			'height' => $_->{'scaledvalue'},
			'bordercolour' => $genes_col,
			'absolutey' => 1,
			'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
		});
	    $self->push($g_x);
	}
}

1;
