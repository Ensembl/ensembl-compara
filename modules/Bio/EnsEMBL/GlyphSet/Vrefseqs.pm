package Bio::EnsEMBL::GlyphSet::Vrefseqs;
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
		'text'      => 'RefSeqs',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vrefseqs','col'),
		'absolutey' => 1,
    });
		
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};

    my $sa = $self->{'container'}->{'sa'};
    my $da = $self->{'container'}->{'da'};

    my $chr_slice = $sa->fetch_by_region('chromosome', $chr);
    my $refseqs   = $da->fetch_Featureset_by_Slice
      ($chr_slice, 'refseqs',150,1); 

    return unless $refseqs->size(); # Return nothing if their is no data
    
    my $refseqs_col = $Config->get( 'Vrefseqs','col' );
	
    $refseqs->scale_to_fit( $Config->get( 'Vrefseqs', 'width' ) );
    $refseqs->stretch(0);
    my @refseqs = $refseqs->get_binvalues();

    foreach (@refseqs){
	$self->push(new Sanger::Graphics::Glyph::Rect({
		'x'      => $_->{'chromosomestart'},
		'y'      => 0,
		'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
		'height' => $_->{'scaledvalue'},
		'bordercolour' => $refseqs_col,
		'absolutey' => 1,
		'href'   => "/@{[$self->{container}{_config_file_name_}]}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
	}));
    }
}

1;
