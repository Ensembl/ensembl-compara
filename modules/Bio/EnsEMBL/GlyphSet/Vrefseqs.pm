package Bio::EnsEMBL::GlyphSet::Vrefseqs;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

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
	$self->push($self->Rect({
		'x'      => $_->{'chromosomestart'},
		'y'      => 0,
		'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
		'height' => $_->{'scaledvalue'},
		'bordercolour' => $refseqs_col,
		'absolutey' => 1,
		'href'   => "/@{[$self->{container}{web_species}]}/contigview?chr=$chr;vc_start=$_->{'chromosomestart'};vc_end=$_->{'chromosomeend'}"
	}));
    }
}

1;
