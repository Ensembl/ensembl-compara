package Bio::EnsEMBL::GlyphSet::snp_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);


sub my_label { return "SNPs"; }

sub features {
    my ($self) = @_;
    my $glob;
    $glob = $self->glob_bp() unless $self->{'config'}->get( $self->check(), 'dep' )>1;
    my @snps = sort { $a->{'type'} cmp $b->{'type'} || $a->{'chr_start'} <=> $b->{'chr_start'} } @{$self->{'container'}->get_all_SNPFeatures_lite( $glob ) };
    if(@snps) {
        $self->{'config'}->{'snp_legend_features'}->{'snps'} = { 'priority' => 1000, 'legend' => [] }
    }
    return @snps;
}

sub href {
    my ($self, $f ) = @_;
    my $ID = $f->{'id'} == 0 ? $f->{'anosnpid'} : $f->{'id'};
    return "/$ENV{'ENSEMBL_SPECIES'}/snpview?snp=$ID&chr=$f->{'chr_name'}&vc_start=$f->{'chr_start'}";
}

sub colour {
    my ($self, $f) = @_;
    my $T = substr($f->{'type'},3,6);
    unless($self->{'config'}->{'snp_types'}{$T}) {
        my %labels = (
            '_coding' => 'Coding SNPs',
            '_utr'    => 'UTR SNPs',
            '_intron' => 'Intronic SNPs',
            '_local'  => 'Flanking SNPs',
            '_'       => 'other SNPs'
        );
        push @{ $self->{'config'}->{'snp_legend_features'}->{'snps'}->{'legend'} }, $labels{"_$T"} => $self->{'colours'}{"_$T"};
        $self->{'config'}->{'snp_types'}{$T}=1;
    }
    return $self->{'colours'}{"_$T"};
}

sub zmenu {
    my ($self, $f ) = @_;
    my $ext_url = $self->{'config'}->{'ext_url'};
    
    my $ID = $f->{'id'} == 0 ? $f->{'anosnpid'} : $f->{'id'};
    my %zmenu = ( 
        'caption'           => "SNP: ".$ID,
        '01:SNP properties' => $self->href( $f ),
        "02:bp: $f->{'chr_start'}" => '',
    );
    $zmenu{'03:dbSNP data'} = $ext_url->get_url('SNP', $f->{'id'}) if $f->{'id'}>0;
    $zmenu{"04:TSC-CSHL data"} = $ext_url->get_url( 'TSC-CSHL', $f->{'tscid'} )  if defined( $f->{'tscid'} ) && $f->{'tscid'}!='';
    $zmenu{"05:HGBASE data"}   = $ext_url->get_url( 'HGBASE',   $f->{'hgbaseid'} ) if defined( $f->{'hgbaseid'} ) && $f->{'hgbaseid'}!='';  
    my $T = substr($f->{'type'},3);
    $zmenu{"06:Type: $T"}   = "" unless $T eq '';  
    return \%zmenu;
}
1;
