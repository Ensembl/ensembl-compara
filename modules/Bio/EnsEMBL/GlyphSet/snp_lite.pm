package Bio::EnsEMBL::GlyphSet::snp_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);

sub my_label { return "SNP"; }

sub features {
    my ($self) = @_;
    return @{$self->{'container'}->get_all_SNPFeatures_lite( $self->glob_bp() )};
}

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/snpview?snp=".$f->{'id'};
}

sub zmenu {
    my ($self, $f ) = @_;
    my $ext_url = $self->{'config'}->{'ext_url'};
    
    my %zmenu = ( 
        'caption'           => "SNP: ".$f->{'id'},
        '01:SNP properties' => $self->href( $f ),
        "02:bp: $f->{'chr_start'}" => '',
        '03:dbSNP data'     => $ext_url->get_url('SNP', $f->{'id'}),
    );
    $zmenu{"04:TSC-CSHL data"} = $ext_url->get_url( 'TSC-CSHL', $f->{'tscid'} )    if defined $f->{'tscid'};
#    $zmenu{"06:CGAP-GAI data"} = $ext_url->get_url( 'CGAP-GAI', $pid );  
    $zmenu{"05:HGBASE data"}   = $ext_url->get_url( 'HGBASE',   $f->{'hgbaseid'} ) if defined $f->{'hgbaseid'};  
    return \%zmenu;
}
1;
