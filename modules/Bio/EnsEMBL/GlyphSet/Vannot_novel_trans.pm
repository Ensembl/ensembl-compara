package Bio::EnsEMBL::GlyphSet::Vannot_novel_trans;
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
		'text'      => 'Novel',
		'font'      => 'Small',
		'colour'	=> $Config->get('_colours','Novel_Transcript'),
		'absolutey' => 1,
    });
    my $label2 = new Sanger::Graphics::Glyph::Text({
		'text'      => 'trans.',
		'font'      => 'Small',
		'colour'	=> $Config->get('_colours','Novel_Transcript'),
		'absolutey' => 1,
    });
		
    $self->label($label);
    $self->label2($label2);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
    my $trans     = $self->{'container'}->{'da'}->get_density_per_chromosome_type( $chr,'novel_trans' );
    my $known_genes = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'known');
    return unless $known_genes->size && $trans->size(); 
    return unless  $trans->{'_biggest_value'} && $known_genes->{'_biggest_value'};
    my $Hscale_factor = $trans->{'_biggest_value'} / $known_genes->{'_biggest_value'};

    my $trans_col = $Config->get( '_colours','Novel_Transcript' );
    $trans->scale_to_fit( $Config->get( 'Vannot_novel_trans', 'width' ) * $Hscale_factor );
    $trans->stretch(0);
    my @trans = $trans->get_binvalues();

    foreach (@trans){
	    my $g_x = new Sanger::Graphics::Glyph::Rect({
		    'x'      => $_->{'chromosomestart'},
		    'y'      => 0,
		    'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
		    'height' => $_->{'scaledvalue'},
		    'bordercolour' => $trans_col,
		    'absolutey' => 1,
		    'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
	    });
	$self->push($g_x);
    }
}

1;
