package Bio::EnsEMBL::GlyphSet::bac_bands;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
sub my_label { return "Band BACs"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
	return $self->{'container'}->get_all_MapFrags( 'bacs_bands' );
}

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( 'bac_bands', 'threshold_navigation' ) || 2e7) * 1000;
    my $ext_url = $self->{'config'}->{'ext_url'};
	my $chr = $f->{'seq'};
	my $chr_start = $f->{'seq_start'};
	my $chr_end = $f->{'seq_end'};

	my $page = ($ENV{'ENSEMBL_SCRIPT'} eq 'cytoview') ? 'contigview' : 'cytoview';
    my $page_link = qq(/$ENV{'ENSEMBL_SPECIES'}/$page?chr=$chr&chr_start=$chr_start&chr_end=$chr_end) ;
	
	my $zmenu = { 
        'caption'   => "BAC: ".$f->name,
        '01:Status: '.$f->status => ''
    };
    
	foreach( $f->synonyms ) {
        $zmenu->{"02:BAC band: $_"} = '';
    }
	
	foreach( $f->embl_accs ) {
        $zmenu->{"03:BAC end: $_"} = $ext_url->get_url( 'EMBL', $_);
    }
	
	$zmenu->{"04:Jump to $page "} = $page_link;
    return $zmenu;
}

sub colour {
    my ($self, $f) = @_;
    my $state = $f->status;
    return $self->{'colours'}{"col_$state"},
           $self->{'colours'}{"lab_$state"},
           $f->length > $self->{'config'}->get( "bac_bands", 'outline_threshold' ) ? 'border' : '';
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->name,'overlaid');
}

1;

