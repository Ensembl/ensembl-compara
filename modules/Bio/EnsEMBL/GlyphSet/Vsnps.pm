package Bio::EnsEMBL::GlyphSet::Vsnps;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Line;
use SiteDefs;

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'};	
    my $label = new Bio::EnsEMBL::Glyph::Text({
		'text'      => 'SNPs',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vsnps','col'),
		'absolutey' => 1,
    });
		
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
    my $snps     = $self->{'container'}->{'da'}->get_density_per_chromosome_type( $chr,'snp' );
    return unless $snps->size(); # Return nothing if their is no 'snp' data in the database - this should stop the barfing completely <g>
    
	my $snps_col = $Config->get( 'Vsnps','col' );
	
   	$snps->scale_to_fit( $Config->get( 'Vsnps', 'width' ) );
	$snps->stretch(0);
	my @snps = $snps->get_binvalues();

    foreach (@snps){
		my $g_x = new Bio::EnsEMBL::Glyph::Rect({
			'x'      => $_->{'chromosomestart'},
			'y'      => 0,
			'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
			'height' => $_->{'scaledvalue'},
			'bordercolour' => $snps_col,
			'absolutey' => 1,
			'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
		});
	    $self->push($g_x);
	}
}

1;
